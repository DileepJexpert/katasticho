package com.katasticho.erp.procurement.service;

import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.StockReceiptLineRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.entity.StockReceipt;
import com.katasticho.erp.procurement.entity.StockReceiptLine;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.StockReceiptRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Stock Receipt (GRN) lifecycle: DRAFT → RECEIVED → CANCELLED
 *
 * receive() loops the lines and calls
 * {@link InventoryService#recordMovement(StockMovementRequest)} for each one
 * — single gate, immutable ledger, balance cache updated atomically.
 *
 * Tax handling is intentionally simpler than invoices: GRNs don't have
 * place-of-supply complexity for our books, so we just compute
 * {@code tax_amount = taxable * gst_rate / 100} per line. The full TaxEngine
 * + tax_line_item ceremony lands when the AP module needs to split input
 * credits across CGST/SGST/IGST in v2.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class StockReceiptService {

    private final StockReceiptRepository receiptRepository;
    private final SupplierRepository supplierRepository;
    private final ItemRepository itemRepository;
    private final WarehouseRepository warehouseRepository;
    private final OrganisationRepository organisationRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final InventoryService inventoryService;
    private final AuditService auditService;

    @Transactional
    public StockReceiptResponse createDraft(CreateStockReceiptRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Supplier supplier = supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(request.supplierId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", request.supplierId()));

        UUID warehouseId = request.warehouseId();
        if (warehouseId == null) {
            Warehouse defaultWh = warehouseRepository
                    .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .orElseThrow(() -> new BusinessException(
                            "No default warehouse configured for this organisation",
                            "INV_NO_DEFAULT_WAREHOUSE", HttpStatus.BAD_REQUEST));
            warehouseId = defaultWh.getId();
        } else {
            warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouseId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Warehouse", request.warehouseId()));
        }

        int periodYear = computeFiscalYear(request.receiptDate(), org.getFiscalYearStart());
        String receiptNumber = generateNumber(orgId, "GRN", periodYear);

        StockReceipt receipt = StockReceipt.builder()
                .orgId(orgId)
                .receiptNumber(receiptNumber)
                .receiptDate(request.receiptDate())
                .warehouseId(warehouseId)
                .supplierId(supplier.getId())
                .supplierInvoiceNo(request.supplierInvoiceNo())
                .supplierInvoiceDate(request.supplierInvoiceDate())
                .status("DRAFT")
                .currency("INR")
                .notes(request.notes())
                .periodYear(periodYear)
                .periodMonth(request.receiptDate().getMonthValue())
                .createdBy(userId)
                .build();

        BigDecimal totalSubtotal = BigDecimal.ZERO;
        BigDecimal totalTax = BigDecimal.ZERO;

        for (int i = 0; i < request.lines().size(); i++) {
            StockReceiptLineRequest lineReq = request.lines().get(i);

            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(lineReq.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", lineReq.itemId()));

            BigDecimal qty = lineReq.quantity().setScale(4, RoundingMode.HALF_UP);
            BigDecimal unitPrice = lineReq.unitPrice().setScale(4, RoundingMode.HALF_UP);
            BigDecimal grossAmount = unitPrice.multiply(qty).setScale(2, RoundingMode.HALF_UP);

            BigDecimal discountPct = nz(lineReq.discountPercent());
            BigDecimal discountAmt = grossAmount.multiply(discountPct)
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

            BigDecimal taxableAmount = grossAmount.subtract(discountAmt);

            BigDecimal gstRate = lineReq.gstRate() != null ? lineReq.gstRate() : item.getGstRate();
            BigDecimal lineTax = taxableAmount.multiply(gstRate)
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
            BigDecimal lineTotal = taxableAmount.add(lineTax);

            String description = (lineReq.description() != null && !lineReq.description().isBlank())
                    ? lineReq.description()
                    : item.getName();
            String hsn = lineReq.hsnCode() != null ? lineReq.hsnCode() : item.getHsnCode();
            String uom = lineReq.unitOfMeasure() != null ? lineReq.unitOfMeasure() : item.getUnitOfMeasure();

            StockReceiptLine line = StockReceiptLine.builder()
                    .lineNumber(i + 1)
                    .itemId(item.getId())
                    .description(description)
                    .hsnCode(hsn)
                    .quantity(qty)
                    .unitOfMeasure(uom)
                    .unitPrice(unitPrice)
                    .discountPercent(discountPct)
                    .discountAmount(discountAmt)
                    .taxableAmount(taxableAmount)
                    .gstRate(gstRate)
                    .taxAmount(lineTax)
                    .lineTotal(lineTotal)
                    .batchNumber(lineReq.batchNumber())
                    .expiryDate(lineReq.expiryDate())
                    .manufacturingDate(lineReq.manufacturingDate())
                    .build();

            receipt.addLine(line);
            totalSubtotal = totalSubtotal.add(taxableAmount);
            totalTax = totalTax.add(lineTax);
        }

        BigDecimal grandTotal = totalSubtotal.add(totalTax);
        receipt.setSubtotal(totalSubtotal.setScale(2, RoundingMode.HALF_UP));
        receipt.setTaxAmount(totalTax.setScale(2, RoundingMode.HALF_UP));
        receipt.setTotalAmount(grandTotal.setScale(2, RoundingMode.HALF_UP));

        receipt = receiptRepository.save(receipt);

        auditService.log("STOCK_RECEIPT", receipt.getId(), "CREATE", null,
                "{\"receiptNumber\":\"" + receipt.getReceiptNumber() + "\",\"total\":\"" + receipt.getTotalAmount() + "\"}");

        log.info("StockReceipt {} created in DRAFT: {} lines, total={}",
                receipt.getReceiptNumber(), receipt.getLines().size(), receipt.getTotalAmount());
        return toResponse(receipt);
    }

    /**
     * Receive: DRAFT → RECEIVED. For each line, post a PURCHASE movement
     * through the single inventory gate. The whole thing runs in one
     * transaction so a failure anywhere rolls back the receipt + every
     * movement that was created so far.
     */
    @Transactional
    public StockReceiptResponse receive(UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        StockReceipt receipt = receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .orElseThrow(() -> BusinessException.notFound("StockReceipt", receiptId));

        if (!"DRAFT".equals(receipt.getStatus())) {
            throw new BusinessException("Only DRAFT receipts can be received",
                    "GRN_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        for (StockReceiptLine line : receipt.getLines()) {
            StockMovementRequest req = new StockMovementRequest(
                    line.getItemId(),
                    receipt.getWarehouseId(),
                    MovementType.PURCHASE,
                    line.getQuantity(),                  // POSITIVE — stock IN
                    line.getUnitPrice(),
                    receipt.getReceiptDate(),
                    ReferenceType.STOCK_RECEIPT,
                    receipt.getId(),
                    receipt.getReceiptNumber(),
                    "GRN " + receipt.getReceiptNumber()
                            + (line.getBatchNumber() != null ? " batch " + line.getBatchNumber() : ""));

            StockMovement movement = inventoryService.recordMovement(req);
            // SERVICE items return null from recordMovement — silently skip them.
            if (movement != null) {
                line.setStockMovementId(movement.getId());
            }
        }

        receipt.setStatus("RECEIVED");
        receipt.setReceivedAt(Instant.now());
        receipt.setReceivedBy(userId);
        receipt = receiptRepository.save(receipt);

        auditService.log("STOCK_RECEIPT", receipt.getId(), "RECEIVE",
                "{\"status\":\"DRAFT\"}",
                "{\"status\":\"RECEIVED\",\"lines\":" + receipt.getLines().size() + "}");

        log.info("StockReceipt {} received: {} stock movements posted",
                receipt.getReceiptNumber(), receipt.getLines().size());
        return toResponse(receipt);
    }

    /**
     * Cancel a receipt. DRAFT → CANCELLED is a simple status flip.
     * RECEIVED → CANCELLED reverses every stock movement the receipt created
     * via {@link InventoryService#reverseMovement(UUID, String)}, which itself
     * appends a REVERSAL row (the original ledger row stays intact).
     */
    @Transactional
    public StockReceiptResponse cancel(UUID receiptId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        StockReceipt receipt = receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .orElseThrow(() -> BusinessException.notFound("StockReceipt", receiptId));

        if ("CANCELLED".equals(receipt.getStatus())) {
            throw new BusinessException("Receipt is already cancelled",
                    "GRN_ALREADY_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        if ("RECEIVED".equals(receipt.getStatus())) {
            for (StockReceiptLine line : receipt.getLines()) {
                if (line.getStockMovementId() != null) {
                    inventoryService.reverseMovement(line.getStockMovementId(),
                            "GRN cancelled: " + (reason != null ? reason : ""));
                }
            }
        }

        receipt.setStatus("CANCELLED");
        receipt.setCancelledAt(Instant.now());
        receipt.setCancelledBy(userId);
        receipt.setCancelReason(reason);
        receipt = receiptRepository.save(receipt);

        auditService.log("STOCK_RECEIPT", receipt.getId(), "CANCEL", null,
                "{\"reason\":\"" + reason + "\"}");

        log.info("StockReceipt {} cancelled: {}", receipt.getReceiptNumber(), reason);
        return toResponse(receipt);
    }

    @Transactional(readOnly = true)
    public StockReceiptResponse getReceipt(UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .map(this::toResponse)
                .orElseThrow(() -> BusinessException.notFound("StockReceipt", receiptId));
    }

    @Transactional(readOnly = true)
    public Page<StockReceiptResponse> listReceipts(UUID supplierId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<StockReceipt> page = supplierId != null
                ? receiptRepository.findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByReceiptDateDesc(orgId, supplierId, pageable)
                : receiptRepository.findByOrgIdAndIsDeletedFalseOrderByReceiptDateDesc(orgId, pageable);
        return page.map(this::toResponse);
    }

    public StockReceiptResponse toResponse(StockReceipt r) {
        Supplier supplier = supplierRepository.findById(r.getSupplierId()).orElse(null);
        Warehouse warehouse = warehouseRepository.findById(r.getWarehouseId()).orElse(null);

        // Bulk-load item SKUs in one query to avoid N+1
        List<UUID> itemIds = r.getLines().stream().map(StockReceiptLine::getItemId).toList();
        Map<UUID, String> skuByItemId = new HashMap<>();
        if (!itemIds.isEmpty()) {
            itemRepository.findAllById(itemIds)
                    .forEach(it -> skuByItemId.put(it.getId(), it.getSku()));
        }

        List<StockReceiptResponse.LineResponse> lineResponses = r.getLines().stream()
                .map(l -> new StockReceiptResponse.LineResponse(
                        l.getId(), l.getLineNumber(), l.getItemId(),
                        skuByItemId.get(l.getItemId()),
                        l.getDescription(), l.getHsnCode(),
                        l.getQuantity(), l.getUnitOfMeasure(), l.getUnitPrice(),
                        l.getDiscountPercent(), l.getTaxableAmount(), l.getGstRate(),
                        l.getTaxAmount(), l.getLineTotal(),
                        l.getBatchNumber(), l.getExpiryDate(), l.getManufacturingDate(),
                        l.getStockMovementId()))
                .toList();

        return new StockReceiptResponse(
                r.getId(), r.getReceiptNumber(), r.getReceiptDate(),
                r.getWarehouseId(), warehouse != null ? warehouse.getName() : null,
                r.getSupplierId(),
                supplier != null ? supplier.getName() : null,
                supplier != null ? supplier.getGstin() : null,
                r.getSupplierInvoiceNo(), r.getSupplierInvoiceDate(),
                r.getStatus(), r.getSubtotal(), r.getTaxAmount(), r.getTotalAmount(),
                r.getCurrency(), r.getNotes(), lineResponses,
                r.getReceivedAt(), r.getCancelledAt(), r.getCancelReason(),
                r.getCreatedAt());
    }

    String generateNumber(UUID orgId, String prefix, int year) {
        var seqOpt = sequenceRepository.findByOrgIdAndPrefixAndYear(orgId, prefix, year);
        long nextVal;
        if (seqOpt.isPresent()) {
            nextVal = seqOpt.get().getNextValue();
            sequenceRepository.incrementAndGet(orgId, prefix, year);
        } else {
            var seq = InvoiceNumberSequence.builder()
                    .id(new InvoiceNumberSequence.InvoiceNumberSequenceId(orgId, prefix, year))
                    .nextValue(2L)
                    .build();
            sequenceRepository.save(seq);
            nextVal = 1L;
        }
        return String.format("%s-%d-%06d", prefix, year, nextVal);
    }

    int computeFiscalYear(LocalDate date, int fiscalYearStartMonth) {
        if (date.getMonthValue() >= fiscalYearStartMonth) {
            return date.getYear();
        }
        return date.getYear() - 1;
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
