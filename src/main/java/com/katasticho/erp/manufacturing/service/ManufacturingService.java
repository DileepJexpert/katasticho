package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.entity.WorkOrderLine;
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
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
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

    @Transactional
    public WorkOrder createWorkOrder(UUID finishedGoodId, UUID warehouseId,
                                     BigDecimal quantityToProduce,
                                     LocalDate plannedStart, LocalDate plannedEnd,
                                     BigDecimal directLaborCost, BigDecimal overheadCost,
                                     String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item fg = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(finishedGoodId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", finishedGoodId));

        if (fg.getItemType() != ItemType.COMPOSITE) {
            throw new BusinessException(
                    "Work orders can only be created for COMPOSITE items",
                    "MFG_NOT_COMPOSITE", HttpStatus.BAD_REQUEST);
        }

        if (quantityToProduce == null || quantityToProduce.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(
                    "Quantity to produce must be positive",
                    "MFG_INVALID_QUANTITY", HttpStatus.BAD_REQUEST);
        }

        List<BomComponent> bom = bomComponentRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, finishedGoodId);
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
        wo.setStatus("IN_PROGRESS");
        wo.setActualStartDate(LocalDate.now());
        recalculateTotalCost(wo);

        wo = workOrderRepository.save(wo);

        log.info("Work order {} issued to production — {} lines, RM cost={} for org {}",
                wo.getWorkOrderNumber(), wo.getLines().size(),
                actualRmCost.toPlainString(), orgId);
        return wo;
    }

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
        }

        wo = workOrderRepository.save(wo);

        log.info("Work order {} received {} FG (total {}/{}) for org {}",
                wo.getWorkOrderNumber(), quantityReceived,
                newTotal, wo.getQuantityToProduce(), orgId);
        return wo;
    }

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
