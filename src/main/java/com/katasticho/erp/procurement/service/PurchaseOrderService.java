package com.katasticho.erp.procurement.service;

import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.dto.StockReceiptLineRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.repository.StockReceiptLineRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Lazy;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PurchaseOrderService {

    private final PurchaseOrderRepository poRepository;
    private final PurchaseOrderLineRepository lineRepository;
    private final SupplierRepository supplierRepository;
    private final ItemRepository itemRepository;
    private final StockReceiptLineRepository stockReceiptLineRepository;
    private final ContactRepository contactRepository;
    @Lazy private final StockReceiptService stockReceiptService;
    @Lazy private final PurchaseBillService purchaseBillService;
    @Lazy private final SupplierRateContractService supplierRateContractService;

    // ── Create ──

    @Transactional
    public PurchaseOrderResponse create(PurchaseOrderRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(request.supplierId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", request.supplierId()));

        String poNumber = generatePoNumber(orgId);

        PurchaseOrder po = PurchaseOrder.builder()
                .orgId(orgId)
                .supplierId(request.supplierId())
                .poNumber(poNumber)
                .status("DRAFT")
                .orderDate(request.orderDate())
                .expectedDeliveryDate(request.expectedDeliveryDate())
                .notes(request.notes())
                .warehouseId(request.warehouseId())
                .build();

        po = poRepository.save(po);

        List<PurchaseOrderLine> lines = buildLines(po.getId(), orgId, request.supplierId(), request.lines());
        lineRepository.saveAll(lines);

        BigDecimal total = lines.stream()
                .map(PurchaseOrderLine::getLineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        po.setTotalAmount(total.setScale(4, RoundingMode.HALF_UP));
        po = poRepository.save(po);

        log.info("PurchaseOrder {} created: {} lines, total={}", po.getPoNumber(), lines.size(), po.getTotalAmount());
        return toResponse(po, lines);
    }

    // ── Update (DRAFT only) ──

    @Transactional
    public PurchaseOrderResponse update(UUID id, PurchaseOrderRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseOrder po = poRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", id));

        if (!"DRAFT".equals(po.getStatus())) {
            throw new BusinessException("Only DRAFT purchase orders can be updated",
                    "PO_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(request.supplierId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", request.supplierId()));

        po.setSupplierId(request.supplierId());
        po.setOrderDate(request.orderDate());
        po.setExpectedDeliveryDate(request.expectedDeliveryDate());
        po.setNotes(request.notes());
        po.setWarehouseId(request.warehouseId());

        lineRepository.deleteByPoId(po.getId());
        List<PurchaseOrderLine> lines = buildLines(po.getId(), orgId, request.supplierId(), request.lines());
        lineRepository.saveAll(lines);

        BigDecimal total = lines.stream()
                .map(PurchaseOrderLine::getLineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        po.setTotalAmount(total.setScale(4, RoundingMode.HALF_UP));
        po = poRepository.save(po);

        log.info("PurchaseOrder {} updated", po.getPoNumber());
        return toResponse(po, lines);
    }

    // ── Send (DRAFT → SENT) ──

    @Transactional
    public PurchaseOrderResponse send(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseOrder po = poRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", id));

        if (!"DRAFT".equals(po.getStatus())) {
            throw new BusinessException("Only DRAFT purchase orders can be sent",
                    "PO_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        po.setStatus("SENT");
        po = poRepository.save(po);

        log.info("PurchaseOrder {} sent to supplier", po.getPoNumber());
        List<PurchaseOrderLine> lines = lineRepository.findByPoId(po.getId());
        return toResponse(po, lines);
    }

    // ── Cancel ──

    @Transactional
    public PurchaseOrderResponse cancel(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseOrder po = poRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", id));

        if ("CANCELLED".equals(po.getStatus()) || "RECEIVED".equals(po.getStatus())) {
            throw new BusinessException("Cannot cancel a " + po.getStatus() + " purchase order",
                    "PO_CANCEL_NOT_ALLOWED", HttpStatus.BAD_REQUEST);
        }

        po.setStatus("CANCELLED");
        po = poRepository.save(po);

        log.info("PurchaseOrder {} cancelled", po.getPoNumber());
        List<PurchaseOrderLine> lines = lineRepository.findByPoId(po.getId());
        return toResponse(po, lines);
    }

    // ── List ──

    @Transactional(readOnly = true)
    public List<PurchaseOrderResponse> list() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<PurchaseOrder> pos = poRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId);
        return pos.stream().map(po -> {
            List<PurchaseOrderLine> lines = lineRepository.findByPoId(po.getId());
            return toResponse(po, lines);
        }).toList();
    }

    // ── Get by ID ──

    @Transactional(readOnly = true)
    public PurchaseOrderResponse getById(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PurchaseOrder po = poRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", id));
        List<PurchaseOrderLine> lines = lineRepository.findByPoId(po.getId());
        return toResponse(po, lines);
    }

    // ── Helpers ──

    private String generatePoNumber(UUID orgId) {
        long count = poRepository.countByOrgIdAndIsDeletedFalse(orgId) + 1;
        return String.format("PO-%05d", count);
    }

    private List<PurchaseOrderLine> buildLines(UUID poId, UUID orgId, UUID supplierId,
                                               List<PurchaseOrderRequest.LineRequest> lineRequests) {
        return lineRequests.stream().map(req -> {
            // Validate item belongs to org
            itemRepository.findByIdAndOrgIdAndIsDeletedFalse(req.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", req.itemId()));

            BigDecimal qty = req.quantity().setScale(4, RoundingMode.HALF_UP);
            // Caller-supplied price wins. When omitted, fall back to the
            // supplier's active rate contract for this item. Refuse the line
            // if neither is available — a PO line without a price is invalid.
            BigDecimal resolvedPrice = req.unitPrice();
            if (resolvedPrice == null) {
                resolvedPrice = supplierRateContractService
                        .findActiveRateForSupplier(supplierId, req.itemId())
                        .orElseThrow(() -> new BusinessException(
                                "PO line for item " + req.itemId() + " has no unit price "
                                        + "and no active supplier rate contract covers it",
                                "PO_LINE_NO_PRICE", HttpStatus.BAD_REQUEST));
            }
            BigDecimal price = resolvedPrice.setScale(4, RoundingMode.HALF_UP);
            BigDecimal lineTotal = qty.multiply(price).setScale(4, RoundingMode.HALF_UP);

            return PurchaseOrderLine.builder()
                    .poId(poId)
                    .itemId(req.itemId())
                    .description(req.description())
                    .quantity(qty)
                    .receivedQuantity(BigDecimal.ZERO)
                    .unitPrice(price)
                    .taxGroupId(req.taxGroupId())
                    .lineTotal(lineTotal)
                    .build();
        }).toList();
    }

    /**
     * Draft a {@link StockReceipt} from a PO, with per-line FKs back to the
     * source PO line and quantities set to ordered − already-received.
     *
     * <p>Remaining qty is computed from the GRN history itself (excludes
     * CANCELLED receipts) — NOT from {@code PurchaseOrderLine.receivedQuantity},
     * because for orgs that have skipped GRNs entirely the field may still be
     * zero. The GRN ledger is authoritative.
     */
    @Transactional
    public StockReceiptResponse createGrnFromPo(UUID poId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseOrder po = poRepository.findByIdAndOrgIdAndIsDeletedFalse(poId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", poId));

        if ("CANCELLED".equals(po.getStatus())) {
            throw new BusinessException("Cannot draft GRN from a cancelled purchase order",
                    "PO_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        List<PurchaseOrderLine> poLines = lineRepository.findByPoId(po.getId());
        if (poLines.isEmpty()) {
            throw new BusinessException("Purchase order has no lines",
                    "PO_EMPTY", HttpStatus.BAD_REQUEST);
        }

        // Pre-load items so we can copy hsn/gst defaults onto the GRN line.
        List<UUID> itemIds = poLines.stream().map(PurchaseOrderLine::getItemId).toList();
        Map<UUID, Item> itemById = new HashMap<>();
        itemRepository.findAllById(itemIds).forEach(it -> itemById.put(it.getId(), it));

        List<StockReceiptLineRequest> grnLines = new ArrayList<>();
        for (PurchaseOrderLine pol : poLines) {
            BigDecimal received = stockReceiptLineRepository
                    .sumQuantityForPurchaseOrderLine(pol.getId());
            if (received == null) received = BigDecimal.ZERO;
            BigDecimal remaining = pol.getQuantity().subtract(received);
            if (remaining.signum() <= 0) {
                continue;
            }
            Item item = itemById.get(pol.getItemId());
            String hsn = item != null ? item.getHsnCode() : null;
            BigDecimal gstRate = item != null && item.getGstRate() != null
                    ? item.getGstRate() : BigDecimal.ZERO;
            String uom = item != null ? item.getUnitOfMeasure() : null;
            grnLines.add(new StockReceiptLineRequest(
                    pol.getItemId(),
                    pol.getDescription(),
                    hsn,
                    remaining.setScale(4, RoundingMode.HALF_UP),
                    uom,
                    pol.getUnitPrice(),
                    BigDecimal.ZERO,
                    gstRate,
                    null, null, null,
                    pol.getId()                        // ← FK back to the PO line
            ));
        }

        if (grnLines.isEmpty()) {
            throw new BusinessException("Purchase order is fully received — nothing left to draft",
                    "PO_FULLY_RECEIVED", HttpStatus.BAD_REQUEST);
        }

        var grnRequest = new CreateStockReceiptRequest(
                po.getSupplierId(),
                po.getWarehouseId(),
                LocalDate.now(),
                null,
                null,
                "Auto-drafted from PO " + po.getPoNumber(),
                null, null, null, null,
                po.getId(),                            // ← top-level PO link
                grnLines);

        return stockReceiptService.createDraft(grnRequest);
    }

    /**
     * Draft a {@link com.katasticho.erp.ap.entity.PurchaseBill} from a PO with
     * per-line FKs back to the PO line. Quantities default to the PO's ordered
     * qty (planner can edit on the draft); price comes from the PO line.
     *
     * <p>Bill date = today. Vendor is the PO's supplier resolved to a contact
     * via supplier.contactId. Throws {@code PO_NO_VENDOR_CONTACT} when the
     * supplier isn't linked to a contact (AP needs a contact, not a supplier).
     */
    @Transactional
    public PurchaseBillResponse createBillFromPo(UUID poId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseOrder po = poRepository.findByIdAndOrgIdAndIsDeletedFalse(poId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", poId));

        if ("CANCELLED".equals(po.getStatus())) {
            throw new BusinessException("Cannot draft bill from a cancelled purchase order",
                    "PO_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        var supplier = supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(po.getSupplierId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", po.getSupplierId()));

        // Find a vendor contact matching the supplier — bill needs a Contact, not a Supplier.
        // Match by display name (case-insensitive). Most orgs maintain a 1:1 supplier/contact.
        Contact vendorContact = contactRepository
                .findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, supplier.getName())
                .filter(c -> c.getContactType() == ContactType.VENDOR
                        || c.getContactType() == ContactType.BOTH)
                .orElseThrow(() -> new BusinessException(
                        "No vendor contact found for supplier '" + supplier.getName()
                                + "' — create a matching vendor contact first",
                        "PO_NO_VENDOR_CONTACT", HttpStatus.BAD_REQUEST));

        List<PurchaseOrderLine> poLines = lineRepository.findByPoId(po.getId());
        if (poLines.isEmpty()) {
            throw new BusinessException("Purchase order has no lines",
                    "PO_EMPTY", HttpStatus.BAD_REQUEST);
        }

        // Pre-load items so we can populate hsn / gst / description.
        List<UUID> itemIds = poLines.stream().map(PurchaseOrderLine::getItemId).toList();
        Map<UUID, Item> itemById = new HashMap<>();
        itemRepository.findAllById(itemIds).forEach(it -> itemById.put(it.getId(), it));

        List<CreatePurchaseBillRequest.BillLineRequest> billLines = new ArrayList<>();
        for (PurchaseOrderLine pol : poLines) {
            Item item = itemById.get(pol.getItemId());
            String description = pol.getDescription() != null
                    ? pol.getDescription()
                    : (item != null ? item.getName() : "");
            String hsn = item != null ? item.getHsnCode() : null;
            BigDecimal gstRate = item != null && item.getGstRate() != null
                    ? item.getGstRate() : BigDecimal.ZERO;
            billLines.add(new CreatePurchaseBillRequest.BillLineRequest(
                    "GOODS",
                    description,
                    hsn,
                    pol.getItemId(),
                    null, null,
                    pol.getQuantity(),
                    pol.getUnitPrice(),
                    BigDecimal.ZERO,
                    gstRate,
                    pol.getTaxGroupId(),
                    null, null,
                    pol.getId()                        // ← FK back to the PO line
            ));
        }

        var billRequest = new CreatePurchaseBillRequest(
                vendorContact.getId(),
                null,
                LocalDate.now(),
                null,
                null,
                false,
                "Auto-drafted from PO " + po.getPoNumber(),
                null,
                null,
                po.getId(),                            // ← top-level PO link
                billLines);

        return purchaseBillService.createBill(billRequest);
    }

    public PurchaseOrderResponse toResponse(PurchaseOrder po, List<PurchaseOrderLine> lines) {
        var supplier = supplierRepository.findById(po.getSupplierId()).orElse(null);

        // Bulk-load item names in one query to avoid N+1
        List<UUID> itemIds = lines.stream().map(PurchaseOrderLine::getItemId).toList();
        Map<UUID, String> nameByItemId = new HashMap<>();
        if (!itemIds.isEmpty()) {
            itemRepository.findAllById(itemIds)
                    .forEach(it -> nameByItemId.put(it.getId(), it.getName()));
        }

        List<PurchaseOrderResponse.LineResponse> lineResponses = lines.stream()
                .map(l -> new PurchaseOrderResponse.LineResponse(
                        l.getId(),
                        l.getPoId(),
                        l.getItemId(),
                        nameByItemId.get(l.getItemId()),
                        l.getDescription(),
                        l.getQuantity(),
                        l.getReceivedQuantity(),
                        l.getUnitPrice(),
                        l.getTaxGroupId(),
                        l.getLineTotal()))
                .toList();

        return new PurchaseOrderResponse(
                po.getId(),
                po.getOrgId(),
                po.getSupplierId(),
                supplier != null ? supplier.getName() : null,
                po.getPoNumber(),
                po.getStatus(),
                po.getOrderDate(),
                po.getExpectedDeliveryDate(),
                po.getNotes(),
                po.getWarehouseId(),
                po.getTotalAmount(),
                lineResponses,
                po.getCreatedAt());
    }
}
