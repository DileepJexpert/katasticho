package com.katasticho.erp.procurement.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
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

        List<PurchaseOrderLine> lines = buildLines(po.getId(), orgId, request.lines());
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
        List<PurchaseOrderLine> lines = buildLines(po.getId(), orgId, request.lines());
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

    private List<PurchaseOrderLine> buildLines(UUID poId, UUID orgId, List<PurchaseOrderRequest.LineRequest> lineRequests) {
        return lineRequests.stream().map(req -> {
            // Validate item belongs to org
            itemRepository.findByIdAndOrgIdAndIsDeletedFalse(req.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", req.itemId()));

            BigDecimal qty = req.quantity().setScale(4, RoundingMode.HALF_UP);
            BigDecimal price = req.unitPrice().setScale(4, RoundingMode.HALF_UP);
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
