package com.katasticho.erp.pos.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.cache.CacheInvalidationService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.contact.dto.ContactLedgerResponse;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.pos.dto.CreateSalesReceiptRequest;
import com.katasticho.erp.pos.dto.CustomerHistoryResponse;
import com.katasticho.erp.pos.dto.SalesReceiptResponse;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import com.katasticho.erp.notification.sms.SmsService;
import com.katasticho.erp.tax.TaxEngine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * POS Sales Receipt — one-shot transaction. No DRAFT state.
 * <ol>
 *   <li>Generate receipt number (SR-YYYY-NNNNNN)</li>
 *   <li>Calculate line totals + tax via TaxEngine</li>
 *   <li>Post journal — DR paid-through, CR Revenue, CR Tax Payable</li>
 *   <li>Deduct stock for tracked items</li>
 *   <li>Return completed receipt</li>
 * </ol>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SalesReceiptService {

    private static final String RECEIPT_PREFIX = "SR";

    private final SalesReceiptRepository receiptRepository;
    private final ItemRepository itemRepository;
    private final StockBatchRepository stockBatchRepository;
    private final WarehouseRepository warehouseRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final ContactRepository contactRepository;
    private final JournalService journalService;
    private final AccountingPostingEngine postingEngine;
    private final InventoryService inventoryService;
    private final BatchService batchService;
    private final TaxEngine taxEngine;
    private final AuditService auditService;
    private final CacheInvalidationService cacheInvalidationService;
    private final OrganisationRepository organisationRepository;
    private final DocumentSnapshotService documentSnapshotService;
    private final ContactLedgerService contactLedgerService;
    private final SmsService smsService;
    private final com.katasticho.erp.organisation.OrgSettingsService orgSettingsService;
    // @Lazy: WhatsAppDocumentService renders receipts (via ReceiptPdfService)
    // which depend back on this service - the common edge of both cycles.
    @org.springframework.context.annotation.Lazy
    private final com.katasticho.erp.notification.whatsapp.WhatsAppDocumentService whatsAppDocumentService;

    @Transactional
    public SalesReceiptResponse create(CreateSalesReceiptRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        // 1. Generate receipt number
        int year = request.receiptDate().getYear();
        String receiptNumber = generateNumber(orgId, RECEIPT_PREFIX, year);

        // 2. Build receipt entity
        SalesReceipt receipt = SalesReceipt.builder()
                .branchId(request.branchId())
                .receiptNumber(receiptNumber)
                .contactId(request.contactId())
                .receiptDate(request.receiptDate())
                .paymentMode(request.paymentMode())
                .paidThroughId(request.paidThroughId())
                .amountReceived(request.amountReceived())
                .upiReference(request.upiReference())
                .notes(request.notes())
                .offlineReceiptNumber(request.offlineReceiptNumber())
                .build();
        receipt.setOrgId(orgId);
        receipt.setCreatedBy(userId);

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        // 3. Process line items — compute tax, build lines
        BigDecimal totalTax = BigDecimal.ZERO;
        BigDecimal cgstTotal = BigDecimal.ZERO;
        BigDecimal sgstTotal = BigDecimal.ZERO;
        BigDecimal igstTotal = BigDecimal.ZERO;
        BigDecimal grossTotal = BigDecimal.ZERO;
        List<TaxLineItem> allTaxLines = new ArrayList<>();

        // Pre-load all items referenced by lines
        List<UUID> itemIds = request.lines().stream()
                .map(CreateSalesReceiptRequest.LineRequest::itemId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<UUID, Item> itemMap = itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, Function.identity()));

        for (int i = 0; i < request.lines().size(); i++) {
            var lineReq = request.lines().get(i);

            BigDecimal lineAmount = lineReq.rate().multiply(lineReq.quantity())
                    .setScale(2, RoundingMode.HALF_UP);

            // Tax calculation — prefer explicit taxGroupId, else item default, else resolve from gstRate
            UUID taxGroupId = lineReq.taxGroupId();
            if (taxGroupId == null && lineReq.itemId() != null) {
                Item item = itemMap.get(lineReq.itemId());
                if (item != null) {
                    taxGroupId = item.getDefaultTaxGroupId();
                    if (taxGroupId == null && item.getGstRate() != null
                            && item.getGstRate().compareTo(BigDecimal.ZERO) > 0) {
                        String stateCode = org.getStateCode();
                        taxGroupId = taxEngine.resolveGroupId(orgId, item.getGstRate(),
                                stateCode, stateCode).orElse(null);
                    }
                }
            }

            boolean isTaxInclusive = Boolean.TRUE.equals(lineReq.taxInclusive());
            BigDecimal taxableBase;
            TaxEngine.TaxCalculationResult taxResult;

            if (isTaxInclusive && taxGroupId != null) {
                // Back-calculate taxable base from MRP (tax-inclusive gross)
                TaxEngine.TaxCalculationResult probe = taxEngine.calculate(
                        orgId, taxGroupId, BigDecimal.valueOf(100), TaxEngine.TransactionType.SALE);
                BigDecimal totalPct = probe.totalTaxAmount();

                if (totalPct.compareTo(BigDecimal.ZERO) > 0) {
                    BigDecimal divisor = BigDecimal.valueOf(100).add(totalPct);
                    taxableBase = lineAmount.multiply(BigDecimal.valueOf(100))
                            .divide(divisor, 2, RoundingMode.HALF_UP);
                } else {
                    taxableBase = lineAmount;
                }
                taxResult = taxEngine.calculate(orgId, taxGroupId, taxableBase, TaxEngine.TransactionType.SALE);
            } else {
                taxableBase = lineAmount;
                taxResult = taxEngine.calculate(orgId, taxGroupId, lineAmount, TaxEngine.TransactionType.SALE);
            }

            BigDecimal lineTax = taxResult.totalTaxAmount();

            BigDecimal convFactor = lineReq.unitConversionFactor();
            BigDecimal baseQty = lineReq.quantity();
            if (convFactor != null && convFactor.compareTo(BigDecimal.ONE) > 0) {
                baseQty = lineReq.quantity().multiply(convFactor)
                        .setScale(4, RoundingMode.HALF_UP);
            }

            Item lineItem = lineReq.itemId() != null ? itemMap.get(lineReq.itemId()) : null;
            BigDecimal mrp = lineItem != null ? lineItem.getMrp() : null;
            BigDecimal discountPerUnit = calculateDiscountPerUnit(mrp, lineReq.rate());
            BigDecimal discountAmount = discountPerUnit.multiply(lineReq.quantity())
                    .setScale(2, RoundingMode.HALF_UP);

            SalesReceiptLine line = SalesReceiptLine.builder()
                    .lineNumber(i + 1)
                    .itemId(lineReq.itemId())
                    .description(lineReq.description() != null ? lineReq.description()
                            : (lineReq.itemId() != null && itemMap.containsKey(lineReq.itemId())
                            ? itemMap.get(lineReq.itemId()).getName() : null))
                    .quantity(lineReq.quantity())
                    .unit(lineReq.unit())
                    .rate(lineReq.rate())
                    .mrp(mrp)
                    .discountPerUnit(discountPerUnit)
                    .discountAmount(discountAmount)
                    .taxGroupId(taxGroupId)
                    .hsnCode(lineReq.hsnCode())
                    .amount(lineAmount)
                    .batchId(lineReq.batchId())
                    .unitUomId(lineReq.unitUomId())
                    .unitConversionFactor(convFactor)
                    .baseQuantity(baseQty)
                    .build();
            receipt.addLine(line);

            grossTotal = grossTotal.add(lineAmount);
            totalTax = totalTax.add(lineTax);

            // Build tax line items and accumulate GST breakdown
            for (TaxEngine.TaxComponent comp : taxResult.components()) {
                String code = comp.rateCode().toUpperCase();
                if (code.contains("CGST")) cgstTotal = cgstTotal.add(comp.amount());
                else if (code.contains("SGST")) sgstTotal = sgstTotal.add(comp.amount());
                else if (code.contains("IGST")) igstTotal = igstTotal.add(comp.amount());

                allTaxLines.add(TaxLineItem.builder()
                        .orgId(orgId)
                        .sourceType("SALES_RECEIPT")
                        .taxRegime("TAX")
                        .componentCode(comp.rateCode())
                        .rate(comp.percentage())
                        .taxableAmount(taxableBase)
                        .taxAmount(comp.amount())
                        .accountCode(comp.glAccountCode())
                        .hsnCode(lineReq.hsnCode())
                        .baseTaxableAmount(taxableBase)
                        .baseTaxAmount(comp.amount())
                        .build());
            }
        }

        // Total = gross line amounts (what customer pays); derive subtotal to avoid rounding gap
        BigDecimal total = grossTotal.setScale(2, RoundingMode.HALF_UP);
        totalTax = totalTax.setScale(2, RoundingMode.HALF_UP);
        BigDecimal subtotal = total.subtract(totalTax);
        receipt.setSubtotal(subtotal);
        receipt.setTaxAmount(totalTax);
        receipt.setCgst(cgstTotal.setScale(2, RoundingMode.HALF_UP));
        receipt.setSgst(sgstTotal.setScale(2, RoundingMode.HALF_UP));
        receipt.setIgst(igstTotal.setScale(2, RoundingMode.HALF_UP));
        receipt.setTotal(total);
        receipt.setGstInvoice(Boolean.TRUE.equals(request.gstInvoice()));
        receipt.setChangeReturned(
                request.amountReceived().subtract(total).max(BigDecimal.ZERO)
                        .setScale(2, RoundingMode.HALF_UP));

        // 3b. Validate stock availability before committing anything — unless the
        // org bills freely (retail counter style). When pos.allow_negative_stock is
        // on, the sale is never blocked for being short; stock simply goes negative
        // and is reconciled later via a stock receipt. Defaults to true so a fresh
        // shop can bill immediately without first loading opening stock for every item.
        boolean allowNegativeStock = Boolean.parseBoolean(
                orgSettingsService.get(orgId, "pos.allow_negative_stock", "true"));
        if (!allowNegativeStock) {
            List<Map.Entry<UUID, BigDecimal>> stockCheckLines = receipt.getLines().stream()
                    .filter(l -> l.getItemId() != null)
                    .map(l -> Map.entry(l.getItemId(),
                            l.getBaseQuantity() != null ? l.getBaseQuantity() : l.getQuantity()))
                    .toList();
            inventoryService.validateStockForSale(orgId, itemMap, stockCheckLines);
        }

        // 4. Persist receipt + lines
        receipt = receiptRepository.save(receipt);

        // Save tax line items
        final UUID receiptId = receipt.getId();
        for (TaxLineItem tli : allTaxLines) {
            tli.setSourceId(receiptId);
        }
        taxLineItemRepository.saveAll(allTaxLines);

        // 5. Post journal — immediate payment, no AR
        JournalEntry journalEntry = postingEngine.postPosReceipt(receipt, allTaxLines, itemMap);
        receipt.setJournalEntryId(journalEntry.getId());
        receiptRepository.save(receipt);

        // 6. Deduct stock for tracked items
        deductStock(receipt, itemMap);

        auditService.log("SALES_RECEIPT", receipt.getId(), "CREATE", null,
                "{\"receiptNumber\":\"" + receiptNumber + "\",\"total\":\"" + total + "\"}");

        cacheInvalidationService.onPosSale(TenantContext.getCurrentOrgId());

        SalesReceiptResponse response = toResponse(receipt);
        documentSnapshotService.createSnapshot("SALES_RECEIPT", receipt.getId(), receipt.getReceiptNumber(), response);

        final UUID smsContactId = receipt.getContactId();
        final BigDecimal smsTotal = receipt.getTotal();
        final String orgName = org.getName();
        if (smsContactId != null) {
            contactRepository.findById(smsContactId).ifPresent(contact -> {
                String phone = (contact.getMobile() != null && !contact.getMobile().isBlank())
                        ? contact.getMobile() : contact.getPhone();
                smsService.sendReceiptSms(orgId, phone, receiptNumber, smsTotal, orgName);
            });
        }
        whatsAppDocumentService.autoSendReceipt(orgId, receipt.getId());

        return response;
    }

    @Transactional(readOnly = true)
    public SalesReceiptResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesReceipt receipt = receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("SalesReceipt", id));
        return toResponse(receipt);
    }

    @Transactional(readOnly = true)
    public PagedResponse<SalesReceiptResponse> list(UUID branchId, LocalDate dateFrom,
                                                     LocalDate dateTo, String paymentMode,
                                                     Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<SalesReceipt> page = receiptRepository.findFiltered(
                orgId.toString(),
                branchId != null ? branchId.toString() : null,
                dateFrom != null ? dateFrom.toString() : null,
                dateTo != null ? dateTo.toString() : null,
                paymentMode,
                pageable);
        return PagedResponse.from(page.map(this::toResponse));
    }

    // Journal posting is now delegated to AccountingPostingEngine

    // ── Stock deduction ─────────────────────────────────────────

    private void deductStock(SalesReceipt receipt, Map<UUID, Item> itemMap) {
        UUID orgId = receipt.getOrgId();
        Warehouse warehouse = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElse(null);
        if (warehouse == null) return;

        for (SalesReceiptLine line : receipt.getLines()) {
            if (line.getItemId() == null) continue;
            Item item = itemMap.get(line.getItemId());
            if (item == null || !item.isTrackInventory()) continue;

            UUID batchId = line.getBatchId();
            // FEFO auto-pick if batch-tracked and no explicit batch
            if (item.isTrackBatches() && batchId == null) {
                var batches = batchService.findFefoBatches(item.getId(), warehouse.getId());
                if (!batches.isEmpty()) {
                    batchId = batches.get(0).getId();
                }
            }

            // Use base quantity for stock deduction (converted to base UoM)
            BigDecimal stockQty = line.getBaseQuantity() != null
                    ? line.getBaseQuantity() : line.getQuantity();

            StockMovementRequest req = new StockMovementRequest(
                    line.getItemId(),
                    warehouse.getId(),
                    MovementType.SALE,
                    stockQty.negate(),
                    line.getRate(),
                    receipt.getReceiptDate(),
                    ReferenceType.SALES_RECEIPT,
                    receipt.getId(),
                    receipt.getReceiptNumber(),
                    "POS Sale " + receipt.getReceiptNumber(),
                    batchId);

            StockMovement movement = inventoryService.recordMovement(req);
            line.setStockMovementId(movement.getId());
        }
    }

    // ── Number generation ───────────────────────────────────────

    private String generateNumber(UUID orgId, String prefix, int year) {
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

    // ── Response mapping ────────────────────────────────────────

    public SalesReceiptResponse toResponse(SalesReceipt receipt) {
        UUID orgId = receipt.getOrgId();

        String contactName = null;
        if (receipt.getContactId() != null) {
            contactName = contactRepository.findById(receipt.getContactId())
                    .map(Contact::getDisplayName)
                    .orElse(null);
        }

        // Load items for line enrichment
        List<UUID> itemIds = receipt.getLines().stream()
                .map(SalesReceiptLine::getItemId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<UUID, Item> itemMap = itemIds.isEmpty()
                ? Map.of()
                : itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, itemIds)
                .stream()
                .collect(Collectors.toMap(Item::getId, Function.identity()));
        List<UUID> batchIds = receipt.getLines().stream()
                .map(SalesReceiptLine::getBatchId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<UUID, StockBatch> batchMap = batchIds.isEmpty()
                ? Map.of()
                : stockBatchRepository.findAllById(batchIds)
                .stream()
                .collect(Collectors.toMap(StockBatch::getId, Function.identity()));

        List<SalesReceiptResponse.LineResponse> lineResponses = receipt.getLines().stream()
                .map(l -> {
                    Item item = l.getItemId() != null ? itemMap.get(l.getItemId()) : null;
                    StockBatch batch = l.getBatchId() != null ? batchMap.get(l.getBatchId()) : null;
                    BigDecimal mrp = l.getMrp() != null ? l.getMrp()
                            : (item != null ? item.getMrp() : null);
                    BigDecimal derivedDiscountPerUnit = calculateDiscountPerUnit(mrp, l.getRate());
                    boolean legacyLineWithoutSnapshot = l.getMrp() == null
                            && derivedDiscountPerUnit.compareTo(BigDecimal.ZERO) > 0;
                    BigDecimal discountPerUnit = l.getDiscountPerUnit() != null && !legacyLineWithoutSnapshot
                            ? l.getDiscountPerUnit()
                            : derivedDiscountPerUnit;
                    BigDecimal derivedDiscountAmount = discountPerUnit.multiply(l.getQuantity())
                            .setScale(2, RoundingMode.HALF_UP);
                    BigDecimal discountAmount = l.getDiscountAmount() != null && !legacyLineWithoutSnapshot
                            ? l.getDiscountAmount()
                            : derivedDiscountAmount;
                    return new SalesReceiptResponse.LineResponse(
                            l.getId(),
                            l.getLineNumber(),
                            l.getItemId(),
                            item != null ? item.getName() : null,
                            item != null ? item.getSku() : null,
                            l.getDescription(),
                            l.getQuantity(),
                            l.getUnit(),
                            mrp,
                            l.getRate(),
                            discountPerUnit,
                            discountAmount,
                            l.getTaxGroupId(),
                            l.getHsnCode(),
                            l.getAmount(),
                            l.getBatchId(),
                            batch != null ? batch.getBatchNumber() : null,
                            batch != null && batch.getExpiryDate() != null
                                    ? batch.getExpiryDate().toString() : null);
                })
                .toList();

        return new SalesReceiptResponse(
                receipt.getId(),
                receipt.getReceiptNumber(),
                receipt.getReceiptDate(),
                receipt.getBranchId(),
                receipt.getContactId(),
                contactName,
                receipt.getSubtotal(),
                receipt.getTaxAmount(),
                receipt.getCgst(),
                receipt.getSgst(),
                receipt.getIgst(),
                receipt.getTotal(),
                receipt.isGstInvoice(),
                receipt.getPaymentMode(),
                receipt.getAmountReceived(),
                receipt.getChangeReturned(),
                receipt.getUpiReference(),
                receipt.getNotes(),
                receipt.getJournalEntryId(),
                receipt.getCreatedAt(),
                lineResponses);
    }

    private BigDecimal calculateDiscountPerUnit(BigDecimal mrp, BigDecimal rate) {
        if (mrp == null || rate == null || mrp.compareTo(rate) <= 0) {
            return BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        }
        return mrp.subtract(rate).setScale(2, RoundingMode.HALF_UP);
    }

    @Transactional(readOnly = true)
    public CustomerHistoryResponse getCustomerHistory(UUID contactId, int days) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        LocalDate from = LocalDate.now().minusDays(days);

        List<SalesReceipt> receipts = receiptRepository.findByContactAndDateRange(
                orgId, contactId, from, PageRequest.of(0, 20));

        BigDecimal totalSpent = receiptRepository.sumTotalByContact(orgId, contactId, from);

        BigDecimal outstanding = BigDecimal.ZERO;
        try {
            ContactLedgerResponse ledger = contactLedgerService.getLedger(
                    contactId, from, LocalDate.now());
            outstanding = ledger.closingBalance() != null ? ledger.closingBalance() : BigDecimal.ZERO;
        } catch (Exception e) {
            log.debug("Could not fetch ledger for customer history: {}", e.getMessage());
        }

        List<CustomerHistoryResponse.ReceiptSummary> summaries = receipts.stream()
                .map(r -> new CustomerHistoryResponse.ReceiptSummary(
                        r.getId(),
                        r.getReceiptNumber(),
                        r.getReceiptDate(),
                        r.getTotal(),
                        r.getPaymentMode() != null ? r.getPaymentMode().name() : "CASH",
                        r.getLines().stream()
                                .map(l -> new CustomerHistoryResponse.ItemSummary(
                                        l.getDescription(),
                                        l.getQuantity(),
                                        l.getUnit(),
                                        l.getAmount()))
                                .collect(Collectors.toList())))
                .collect(Collectors.toList());

        String phone = contact.getMobile() != null && !contact.getMobile().isBlank()
                ? contact.getMobile() : contact.getPhone();

        return new CustomerHistoryResponse(
                contactId,
                contact.getDisplayName(),
                phone,
                outstanding,
                totalSpent != null ? totalSpent : BigDecimal.ZERO,
                receipts.size(),
                days,
                summaries);
    }
}
