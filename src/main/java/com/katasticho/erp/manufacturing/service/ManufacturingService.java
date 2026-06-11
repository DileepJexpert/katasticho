package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.ManufacturingWipPostingRule;
import com.katasticho.erp.accounting.posting.PostingContext;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.ProductionCostSummary;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.entity.WorkOrderLine;
import com.katasticho.erp.manufacturing.repository.ProductionCostSummaryRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderLineRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ManufacturingService {

    private final WorkOrderRepository workOrderRepository;
    private final WorkOrderLineRepository workOrderLineRepository;
    private final BomComponentRepository bomComponentRepository;
    private final ItemRepository itemRepository;
    private final InventoryService inventoryService;
    private final SalesOrderRepository salesOrderRepository;
    private final WarehouseRepository warehouseRepository;
    private final JournalService journalService;
    private final ManufacturingWipPostingRule wipPostingRule;
    private final ProductionCostSummaryRepository costSummaryRepository;

    // ── Work Order CRUD ──────────────────────────────────────────────

    @Transactional
    public WorkOrder createWorkOrder(UUID finishedGoodId, UUID warehouseId,
                                     BigDecimal quantityToProduce,
                                     LocalDate plannedStart, LocalDate plannedEnd,
                                     BigDecimal directLaborCost, BigDecimal overheadCost,
                                     String notes) {
        return createWorkOrder(finishedGoodId, warehouseId, quantityToProduce,
                plannedStart, plannedEnd, directLaborCost, overheadCost,
                notes, false, null, false);
    }

    @Transactional
    public WorkOrder createWorkOrder(UUID finishedGoodId, UUID warehouseId,
                                     BigDecimal quantityToProduce,
                                     LocalDate plannedStart, LocalDate plannedEnd,
                                     BigDecimal directLaborCost, BigDecimal overheadCost,
                                     String notes, boolean backflushMode,
                                     Integer bomVersion, boolean isDisassembly) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item fg = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(finishedGoodId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", finishedGoodId));

        if (!isDisassembly && fg.getItemType() != ItemType.COMPOSITE) {
            throw new BusinessException(
                    "Work orders can only be created for COMPOSITE items",
                    "MFG_NOT_COMPOSITE", HttpStatus.BAD_REQUEST);
        }

        if (quantityToProduce == null || quantityToProduce.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(
                    "Quantity to produce must be positive",
                    "MFG_INVALID_QUANTITY", HttpStatus.BAD_REQUEST);
        }

        List<BomComponent> bom;
        int resolvedVersion;
        if (bomVersion != null) {
            bom = bomComponentRepository
                    .findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                            orgId, finishedGoodId, bomVersion);
            resolvedVersion = bomVersion;
        } else {
            bom = bomComponentRepository
                    .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, finishedGoodId);
            resolvedVersion = bomComponentRepository.findMaxVersion(orgId, finishedGoodId);
        }

        if (bom.isEmpty()) {
            throw new BusinessException(
                    "No BOM components defined for item " + fg.getSku(),
                    "MFG_NO_BOM", HttpStatus.BAD_REQUEST);
        }

        int nextNum = workOrderRepository.findMaxWorkOrderNumber(orgId) + 1;
        String woNumber = String.format("WO-%05d", nextNum);

        WorkOrder wo = WorkOrder.builder()
                .workOrderNumber(woNumber)
                .finishedGoodId(finishedGoodId)
                .warehouseId(warehouseId)
                .quantityToProduce(quantityToProduce)
                .plannedStartDate(plannedStart)
                .plannedEndDate(plannedEnd)
                .directLaborCost(directLaborCost != null ? directLaborCost : BigDecimal.ZERO)
                .overheadCost(overheadCost != null ? overheadCost : BigDecimal.ZERO)
                .notes(notes)
                .status("DRAFT")
                .backflushMode(backflushMode)
                .bomVersion(resolvedVersion > 0 ? resolvedVersion : null)
                .disassembly(isDisassembly)
                .lines(new ArrayList<>())
                .build();

        wo = workOrderRepository.save(wo);

        BigDecimal totalRmCost = BigDecimal.ZERO;
        for (BomComponent comp : bom) {
            BigDecimal requiredQty = comp.getQuantity().multiply(quantityToProduce)
                    .setScale(4, RoundingMode.HALF_UP);

            Item childItem = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(comp.getChildItemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", comp.getChildItemId()));

            BigDecimal cost = childItem.getPurchasePrice() != null
                    ? childItem.getPurchasePrice() : BigDecimal.ZERO;
            BigDecimal lineCost = cost.multiply(requiredQty).setScale(2, RoundingMode.HALF_UP);

            WorkOrderLine line = WorkOrderLine.builder()
                    .workOrder(wo)
                    .itemId(comp.getChildItemId())
                    .requiredQty(requiredQty)
                    .unitCost(cost)
                    .lineCost(lineCost)
                    .status("PENDING")
                    .build();

            wo.getLines().add(line);
            totalRmCost = totalRmCost.add(lineCost);
        }

        wo.setRawMaterialCost(totalRmCost);
        recalculateTotalCost(wo);

        wo = workOrderRepository.save(wo);

        log.info("Created work order {} for item {} qty={} with {} lines for org {}",
                woNumber, fg.getSku(), quantityToProduce, bom.size(), orgId);
        return wo;
    }

    @Transactional(readOnly = true)
    public WorkOrder getWorkOrder(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", id));
    }

    @Transactional(readOnly = true)
    public Page<WorkOrder> listWorkOrders(String status, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (status != null && !status.isBlank()) {
            return workOrderRepository.findByOrgIdAndStatusAndIsDeletedFalse(orgId, status, pageable);
        }
        return workOrderRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);
    }

    // ── Issue to Production ──────────────────────────────────────────

    @Transactional
    public WorkOrder issueToProduction(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if (!"DRAFT".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT work orders can be issued to production, current: " + wo.getStatus(),
                    "MFG_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        if (!wo.isBackflushMode()) {
            issueMaterials(wo);
        }

        wo.setStatus("IN_PROGRESS");
        wo.setActualStartDate(LocalDate.now());
        recalculateTotalCost(wo);

        postWipJournal(wo);

        wo = workOrderRepository.save(wo);

        log.info("Work order {} issued to production — {} lines, RM cost={} for org {}",
                wo.getWorkOrderNumber(), wo.getLines().size(),
                wo.getRawMaterialCost().toPlainString(), orgId);
        return wo;
    }

    private void issueMaterials(WorkOrder wo) {
        BigDecimal actualRmCost = BigDecimal.ZERO;
        for (WorkOrderLine line : wo.getLines()) {
            if (line.isDeleted()) continue;

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    wo.getWarehouseId(),
                    MovementType.PRODUCTION_ISSUE,
                    line.getRequiredQty().negate(),
                    line.getUnitCost(),
                    LocalDate.now(),
                    ReferenceType.WORK_ORDER,
                    wo.getId(),
                    wo.getWorkOrderNumber(),
                    "Production issue for " + wo.getWorkOrderNumber()
            ));

            line.setIssuedQty(line.getRequiredQty());
            line.setStatus("ISSUED");
            BigDecimal lineCost = line.getUnitCost().multiply(line.getIssuedQty())
                    .setScale(2, RoundingMode.HALF_UP);
            line.setLineCost(lineCost);
            actualRmCost = actualRmCost.add(lineCost);
        }
        wo.setRawMaterialCost(actualRmCost);
    }

    // ── Receive Finished Goods ───────────────────────────────────────

    @Transactional
    public WorkOrder receiveFinishedGoods(UUID workOrderId, BigDecimal quantityReceived) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if (!"IN_PROGRESS".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Only IN_PROGRESS work orders can receive finished goods, current: " + wo.getStatus(),
                    "MFG_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        if (quantityReceived == null || quantityReceived.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Received quantity must be positive",
                    "MFG_INVALID_QUANTITY", HttpStatus.BAD_REQUEST);
        }

        BigDecimal newTotal = wo.getQuantityProduced().add(quantityReceived);
        if (newTotal.compareTo(wo.getQuantityToProduce()) > 0) {
            throw new BusinessException(
                    "Cannot receive more than planned quantity. Planned: "
                            + wo.getQuantityToProduce() + ", already received: "
                            + wo.getQuantityProduced() + ", trying: " + quantityReceived,
                    "MFG_EXCEEDS_PLANNED", HttpStatus.BAD_REQUEST);
        }

        if (wo.isBackflushMode()) {
            backflushMaterials(wo, quantityReceived);
        }

        recalculateTotalCost(wo);
        BigDecimal fgUnitCost = wo.getQuantityToProduce().compareTo(BigDecimal.ZERO) > 0
                ? wo.getTotalCost().divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        inventoryService.recordMovement(new StockMovementRequest(
                wo.getFinishedGoodId(),
                wo.getWarehouseId(),
                MovementType.PRODUCTION_RECEIVE,
                quantityReceived,
                fgUnitCost,
                LocalDate.now(),
                ReferenceType.WORK_ORDER,
                wo.getId(),
                wo.getWorkOrderNumber(),
                "Finished goods receipt for " + wo.getWorkOrderNumber()
        ));

        wo.setQuantityProduced(newTotal);
        wo.setUnitCost(fgUnitCost);

        if (newTotal.compareTo(wo.getQuantityToProduce()) >= 0) {
            wo.setStatus("COMPLETED");
            wo.setActualEndDate(LocalDate.now());
            for (WorkOrderLine line : wo.getLines()) {
                if (!line.isDeleted()) {
                    line.setStatus("COMPLETED");
                }
            }

            postCompletionJournal(wo);
            buildCostSummary(wo);
        }

        wo = workOrderRepository.save(wo);

        log.info("Work order {} received {} FG (total {}/{}) for org {}",
                wo.getWorkOrderNumber(), quantityReceived,
                newTotal, wo.getQuantityToProduce(), orgId);
        return wo;
    }

    // ── Backflush: auto-issue RM proportional to FG received ─────────

    private void backflushMaterials(WorkOrder wo, BigDecimal quantityReceived) {
        BigDecimal ratio = quantityReceived.divide(wo.getQuantityToProduce(), 8, RoundingMode.HALF_UP);
        BigDecimal actualRmCost = wo.getRawMaterialCost();

        for (WorkOrderLine line : wo.getLines()) {
            if (line.isDeleted()) continue;

            BigDecimal issueQty = line.getRequiredQty().multiply(ratio)
                    .setScale(4, RoundingMode.HALF_UP);

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    wo.getWarehouseId(),
                    MovementType.PRODUCTION_ISSUE,
                    issueQty.negate(),
                    line.getUnitCost(),
                    LocalDate.now(),
                    ReferenceType.WORK_ORDER,
                    wo.getId(),
                    wo.getWorkOrderNumber(),
                    "Backflush issue for " + wo.getWorkOrderNumber()
            ));

            BigDecimal newIssued = line.getIssuedQty().add(issueQty);
            line.setIssuedQty(newIssued);
            line.setStatus("ISSUED");
            BigDecimal lineCost = line.getUnitCost().multiply(newIssued)
                    .setScale(2, RoundingMode.HALF_UP);
            line.setLineCost(lineCost);
            actualRmCost = actualRmCost.add(line.getUnitCost().multiply(issueQty)
                    .setScale(2, RoundingMode.HALF_UP));
        }
        wo.setRawMaterialCost(actualRmCost);
    }

    // ── Disassembly ──────────────────────────────────────────────────

    @Transactional
    public WorkOrder createDisassemblyOrder(UUID finishedGoodId, UUID warehouseId,
                                             BigDecimal quantityToDisassemble,
                                             String notes) {
        return createWorkOrder(finishedGoodId, warehouseId, quantityToDisassemble,
                null, null, null, null, notes, false, null, true);
    }

    @Transactional
    public WorkOrder executeDisassembly(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if (!wo.isDisassembly()) {
            throw new BusinessException("This work order is not a disassembly order",
                    "MFG_NOT_DISASSEMBLY", HttpStatus.BAD_REQUEST);
        }
        if (!"DRAFT".equals(wo.getStatus())) {
            throw new BusinessException("Only DRAFT disassembly orders can be executed",
                    "MFG_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        inventoryService.recordMovement(new StockMovementRequest(
                wo.getFinishedGoodId(),
                wo.getWarehouseId(),
                MovementType.PRODUCTION_ISSUE,
                wo.getQuantityToProduce().negate(),
                wo.getUnitCost(),
                LocalDate.now(),
                ReferenceType.WORK_ORDER,
                wo.getId(),
                wo.getWorkOrderNumber(),
                "Disassembly — FG consumed: " + wo.getWorkOrderNumber()
        ));

        for (WorkOrderLine line : wo.getLines()) {
            if (line.isDeleted()) continue;

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    wo.getWarehouseId(),
                    MovementType.PRODUCTION_RECEIVE,
                    line.getRequiredQty(),
                    line.getUnitCost(),
                    LocalDate.now(),
                    ReferenceType.WORK_ORDER,
                    wo.getId(),
                    wo.getWorkOrderNumber(),
                    "Disassembly — component recovered: " + wo.getWorkOrderNumber()
            ));

            line.setIssuedQty(line.getRequiredQty());
            line.setStatus("COMPLETED");
        }

        wo.setQuantityProduced(wo.getQuantityToProduce());
        wo.setStatus("COMPLETED");
        wo.setActualStartDate(LocalDate.now());
        wo.setActualEndDate(LocalDate.now());

        wo = workOrderRepository.save(wo);
        log.info("Disassembly order {} executed for org {}", wo.getWorkOrderNumber(), orgId);
        return wo;
    }

    // ── Update Costs ─────────────────────────────────────────────────

    @Transactional
    public WorkOrder updateCosts(UUID workOrderId, BigDecimal directLaborCost, BigDecimal overheadCost) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if ("COMPLETED".equals(wo.getStatus()) || "CANCELLED".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Cannot update costs on a " + wo.getStatus() + " work order",
                    "MFG_WORK_ORDER_FINALIZED", HttpStatus.BAD_REQUEST);
        }

        if (directLaborCost != null) wo.setDirectLaborCost(directLaborCost);
        if (overheadCost != null) wo.setOverheadCost(overheadCost);
        recalculateTotalCost(wo);

        wo = workOrderRepository.save(wo);
        log.info("Work order {} costs updated: labor={}, overhead={}, total={} for org {}",
                wo.getWorkOrderNumber(), wo.getDirectLaborCost(),
                wo.getOverheadCost(), wo.getTotalCost(), orgId);
        return wo;
    }

    // ── Cancel ────────────────────────────────────────────────────────

    @Transactional
    public WorkOrder cancelWorkOrder(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if ("COMPLETED".equals(wo.getStatus())) {
            throw new BusinessException("Completed work orders cannot be cancelled",
                    "MFG_ALREADY_COMPLETED", HttpStatus.BAD_REQUEST);
        }
        if ("CANCELLED".equals(wo.getStatus())) {
            throw new BusinessException("Work order is already cancelled",
                    "MFG_ALREADY_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        if ("IN_PROGRESS".equals(wo.getStatus())) {
            for (WorkOrderLine line : wo.getLines()) {
                if (line.isDeleted() || line.getIssuedQty().compareTo(BigDecimal.ZERO) == 0) continue;

                inventoryService.recordMovement(new StockMovementRequest(
                        line.getItemId(),
                        wo.getWarehouseId(),
                        MovementType.ADJUSTMENT,
                        line.getIssuedQty(),
                        line.getUnitCost(),
                        LocalDate.now(),
                        ReferenceType.WORK_ORDER,
                        wo.getId(),
                        wo.getWorkOrderNumber(),
                        "Reversal — work order " + wo.getWorkOrderNumber() + " cancelled"
                ));
            }

            if (wo.getWipJournalEntryId() != null) {
                journalService.reverseEntry(wo.getWipJournalEntryId());
            }
        }

        wo.setStatus("CANCELLED");
        for (WorkOrderLine line : wo.getLines()) {
            if (!line.isDeleted()) {
                line.setStatus("CANCELLED");
            }
        }

        wo = workOrderRepository.save(wo);
        log.info("Work order {} cancelled for org {}", wo.getWorkOrderNumber(), orgId);
        return wo;
    }

    // ── SO → WO ──────────────────────────────────────────────────────

    @Transactional
    public List<WorkOrder> createWorkOrdersFromSalesOrder(UUID salesOrderId, UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesOrder so = salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(salesOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("SalesOrder", salesOrderId));

        if (!"CONFIRMED".equals(so.getStatus()) && !"BACKORDER".equals(so.getStatus())) {
            throw new BusinessException(
                    "Work orders can only be created from CONFIRMED or BACKORDER sales orders",
                    "MFG_SO_NOT_CONFIRMED", HttpStatus.BAD_REQUEST);
        }

        UUID effectiveWarehouseId = warehouseId;
        if (effectiveWarehouseId == null) {
            effectiveWarehouseId = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .orElseThrow(() -> new BusinessException("No default warehouse configured",
                            "WAREHOUSE_NOT_FOUND", HttpStatus.BAD_REQUEST))
                    .getId();
        }

        List<WorkOrder> created = new ArrayList<>();
        for (SalesOrderLine line : so.getLines()) {
            if (line.getItemId() == null) continue;

            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(line.getItemId(), orgId)
                    .orElse(null);
            if (item == null || item.getItemType() != ItemType.COMPOSITE) continue;

            List<BomComponent> bom = bomComponentRepository
                    .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, line.getItemId());
            if (bom.isEmpty()) continue;

            WorkOrder wo = createWorkOrder(
                    line.getItemId(), effectiveWarehouseId, line.getQuantity(),
                    null, null, null, null,
                    "Auto-created from " + so.getSalesorderNumber());
            wo.setSalesOrderId(salesOrderId);
            wo = workOrderRepository.save(wo);
            created.add(wo);
        }

        if (created.isEmpty()) {
            throw new BusinessException(
                    "No composite items with BOM found in sales order " + so.getSalesorderNumber(),
                    "MFG_SO_NO_COMPOSITE_ITEMS", HttpStatus.BAD_REQUEST);
        }

        log.info("Created {} work orders from SO {} for org {}",
                created.size(), so.getSalesorderNumber(), orgId);
        return created;
    }

    // ── Production Reports ───────────────────────────────────────────

    @Transactional(readOnly = true)
    public ProductionCostSummary getCostVariance(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return costSummaryRepository.findByWorkOrderIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("ProductionCostSummary", workOrderId));
    }

    @Transactional(readOnly = true)
    public Page<ProductionCostSummary> listCostVariances(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return costSummaryRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getWipValuation() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<WorkOrder> wipOrders = workOrderRepository
                .findByOrgIdAndStatusInAndIsDeletedFalse(orgId, List.of("IN_PROGRESS"));

        BigDecimal totalWipValue = BigDecimal.ZERO;
        List<Map<String, Object>> details = new ArrayList<>();

        for (WorkOrder wo : wipOrders) {
            recalculateTotalCost(wo);
            BigDecimal wipValue = wo.getTotalCost();
            totalWipValue = totalWipValue.add(wipValue);

            Map<String, Object> detail = new HashMap<>();
            detail.put("workOrderId", wo.getId());
            detail.put("workOrderNumber", wo.getWorkOrderNumber());
            detail.put("finishedGoodId", wo.getFinishedGoodId());
            detail.put("rawMaterialCost", wo.getRawMaterialCost());
            detail.put("directLaborCost", wo.getDirectLaborCost());
            detail.put("overheadCost", wo.getOverheadCost());
            detail.put("totalWipValue", wipValue);
            detail.put("quantityToProduce", wo.getQuantityToProduce());
            detail.put("quantityProduced", wo.getQuantityProduced());
            detail.put("percentComplete", wo.getQuantityToProduce().signum() > 0
                    ? wo.getQuantityProduced().divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP)
                            .multiply(BigDecimal.valueOf(100)).setScale(1, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO);
            details.add(detail);
        }

        Map<String, Object> result = new HashMap<>();
        result.put("totalWipValue", totalWipValue);
        result.put("wipOrderCount", wipOrders.size());
        result.put("details", details);
        return result;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getConsumptionReport(UUID finishedGoodId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<WorkOrder> completed = workOrderRepository
                .findByOrgIdAndStatusInAndIsDeletedFalse(orgId, List.of("COMPLETED"));

        Map<UUID, BigDecimal> totalConsumed = new HashMap<>();
        Map<UUID, BigDecimal> totalCost = new HashMap<>();

        for (WorkOrder wo : completed) {
            if (finishedGoodId != null && !finishedGoodId.equals(wo.getFinishedGoodId())) continue;
            for (WorkOrderLine line : wo.getLines()) {
                if (line.isDeleted()) continue;
                totalConsumed.merge(line.getItemId(), line.getIssuedQty(), BigDecimal::add);
                totalCost.merge(line.getItemId(), line.getLineCost(), BigDecimal::add);
            }
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (var entry : totalConsumed.entrySet()) {
            Item item = itemRepository.findById(entry.getKey()).orElse(null);
            Map<String, Object> row = new HashMap<>();
            row.put("itemId", entry.getKey());
            row.put("itemName", item != null ? item.getName() : null);
            row.put("sku", item != null ? item.getSku() : null);
            row.put("totalConsumed", entry.getValue());
            row.put("totalCost", totalCost.getOrDefault(entry.getKey(), BigDecimal.ZERO));
            result.add(row);
        }
        return result;
    }

    // ── BOM Versioning ───────────────────────────────────────────────

    @Transactional
    public int createBomVersion(UUID parentItemId, String changeNotes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item parent = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", parentItemId));

        if (parent.getItemType() != ItemType.COMPOSITE) {
            throw new BusinessException("BOM versioning only applies to COMPOSITE items",
                    "MFG_NOT_COMPOSITE", HttpStatus.BAD_REQUEST);
        }

        int currentMax = bomComponentRepository.findMaxVersion(orgId, parentItemId);
        int newVersion = currentMax + 1;

        List<BomComponent> current = bomComponentRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);

        for (BomComponent comp : current) {
            if (comp.getEffectiveTo() == null) {
                comp.setEffectiveTo(LocalDate.now());
                bomComponentRepository.save(comp);
            }
        }

        for (BomComponent comp : current) {
            BomComponent newComp = BomComponent.builder()
                    .parentItemId(parentItemId)
                    .childItemId(comp.getChildItemId())
                    .quantity(comp.getQuantity())
                    .version(newVersion)
                    .effectiveFrom(LocalDate.now())
                    .changeNotes(changeNotes)
                    .build();
            bomComponentRepository.save(newComp);
        }

        log.info("Created BOM version {} for item {} ({} components) for org {}",
                newVersion, parent.getSku(), current.size(), orgId);
        return newVersion;
    }

    @Transactional(readOnly = true)
    public List<BomComponent> getBomVersion(UUID parentItemId, int version) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return bomComponentRepository
                .findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                        orgId, parentItemId, version);
    }

    @Transactional(readOnly = true)
    public int getLatestBomVersion(UUID parentItemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return bomComponentRepository.findMaxVersion(orgId, parentItemId);
    }

    // ── WIP Journal Posting ──────────────────────────────────────────

    private void postWipJournal(WorkOrder wo) {
        try {
            PostingContext ctx = PostingContext.manufacturingWip(wo);
            JournalEntry entry = journalService.postJournal(wipPostingRule.generate(ctx));
            wo.setWipJournalEntryId(entry.getId());
            log.info("WIP journal {} posted for work order {}", entry.getEntryNumber(), wo.getWorkOrderNumber());
        } catch (Exception e) {
            log.warn("WIP journal posting failed for work order {} — {}", wo.getWorkOrderNumber(), e.getMessage());
        }
    }

    private void postCompletionJournal(WorkOrder wo) {
        try {
            PostingContext ctx = PostingContext.manufacturingCompletion(wo);
            JournalEntry entry = journalService.postJournal(wipPostingRule.generate(ctx));
            wo.setJournalEntryId(entry.getId());
            log.info("Completion journal {} posted for work order {}", entry.getEntryNumber(), wo.getWorkOrderNumber());
        } catch (Exception e) {
            log.warn("Completion journal posting failed for work order {} — {}", wo.getWorkOrderNumber(), e.getMessage());
        }
    }

    // ── Cost Summary (on completion) ─────────────────────────────────

    private void buildCostSummary(WorkOrder wo) {
        BigDecimal plannedRm = BigDecimal.ZERO;
        for (WorkOrderLine line : wo.getLines()) {
            if (line.isDeleted()) continue;
            plannedRm = plannedRm.add(line.getUnitCost().multiply(line.getRequiredQty())
                    .setScale(2, RoundingMode.HALF_UP));
        }

        BigDecimal plannedLabor = wo.getDirectLaborCost();
        BigDecimal plannedOverhead = wo.getOverheadCost();
        BigDecimal actualRm = wo.getRawMaterialCost();
        BigDecimal actualLabor = wo.getDirectLaborCost();
        BigDecimal actualOverhead = wo.getOverheadCost();

        BigDecimal plannedTotal = plannedRm.add(plannedLabor).add(plannedOverhead);
        BigDecimal actualTotal = actualRm.add(actualLabor).add(actualOverhead);

        BigDecimal matVariance = actualRm.subtract(plannedRm);
        BigDecimal laborVariance = actualLabor.subtract(plannedLabor);
        BigDecimal overheadVariance = actualOverhead.subtract(plannedOverhead);
        BigDecimal totalVariance = actualTotal.subtract(plannedTotal);

        BigDecimal yieldPct = wo.getQuantityToProduce().signum() > 0
                ? wo.getQuantityProduced().divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP)
                        .multiply(BigDecimal.valueOf(100)).setScale(2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        ProductionCostSummary summary = ProductionCostSummary.builder()
                .workOrderId(wo.getId())
                .workOrderNumber(wo.getWorkOrderNumber())
                .finishedGoodId(wo.getFinishedGoodId())
                .plannedRmCost(plannedRm)
                .actualRmCost(actualRm)
                .plannedLaborCost(plannedLabor)
                .actualLaborCost(actualLabor)
                .plannedOverhead(plannedOverhead)
                .actualOverhead(actualOverhead)
                .plannedTotal(plannedTotal)
                .actualTotal(actualTotal)
                .materialVariance(matVariance)
                .laborVariance(laborVariance)
                .overheadVariance(overheadVariance)
                .totalVariance(totalVariance)
                .plannedQty(wo.getQuantityToProduce())
                .producedQty(wo.getQuantityProduced())
                .scrapQty(wo.getScrapQty())
                .yieldPercentage(yieldPct)
                .completedAt(Instant.now())
                .build();

        costSummaryRepository.save(summary);
        log.info("Cost summary built for work order {} — variance={}", wo.getWorkOrderNumber(), totalVariance);
    }

    // ── Internal ──────────────────────────────────────────────────────

    private void recalculateTotalCost(WorkOrder wo) {
        BigDecimal total = wo.getRawMaterialCost()
                .add(wo.getDirectLaborCost())
                .add(wo.getOverheadCost());
        wo.setTotalCost(total);

        if (wo.getQuantityToProduce().compareTo(BigDecimal.ZERO) > 0) {
            wo.setUnitCost(total.divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP));
        }
    }
}
