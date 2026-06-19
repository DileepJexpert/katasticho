package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.ManufacturingWipPostingRule;
import com.katasticho.erp.accounting.posting.PostingContext;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.BomAlternateRepository;
import com.katasticho.erp.inventory.repository.BomCoProductRepository;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.BatchTraceService;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.ProductionCostSummary;
import com.katasticho.erp.manufacturing.entity.ProductionScrap;
import com.katasticho.erp.manufacturing.entity.ScrapReasonCode;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.entity.WorkOrderLine;
import com.katasticho.erp.manufacturing.repository.ProductionCostSummaryRepository;
import com.katasticho.erp.manufacturing.repository.ProductionScrapRepository;
import com.katasticho.erp.manufacturing.repository.ScrapReasonCodeRepository;
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
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.UUID;
import java.util.stream.Collectors;

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
    private final BomAlternateRepository bomAlternateRepository;
    private final BomCoProductRepository bomCoProductRepository;
    private final ApprovalWorkflowService approvalWorkflowService;
    private final ProductionScrapRepository productionScrapRepository;
    private final ScrapReasonCodeRepository scrapReasonCodeRepository;
    private final StockBatchRepository stockBatchRepository;
    private final BatchTraceService batchTraceService;
    private final StockBalanceRepository stockBalanceRepository;

    private static final BigDecimal HUNDRED = BigDecimal.valueOf(100);
    private static final Set<String> VALID_PRIORITIES = Set.of("URGENT", "HIGH", "NORMAL", "LOW");

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
        return createWorkOrder(finishedGoodId, warehouseId, quantityToProduce,
                plannedStart, plannedEnd, directLaborCost, overheadCost,
                notes, backflushMode, bomVersion, isDisassembly, null);
    }

    @Transactional
    public WorkOrder createWorkOrder(UUID finishedGoodId, UUID warehouseId,
                                     BigDecimal quantityToProduce,
                                     LocalDate plannedStart, LocalDate plannedEnd,
                                     BigDecimal directLaborCost, BigDecimal overheadCost,
                                     String notes, boolean backflushMode,
                                     Integer bomVersion, boolean isDisassembly,
                                     String priority) {
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
                .priority(normalizePriority(priority, true))
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
        wo = applyApprovalWorkflowIfMatched(wo);

        log.info("Created work order {} for item {} qty={} with {} lines for org {}",
                woNumber, fg.getSku(), quantityToProduce, bom.size(), orgId);
        return wo;
    }

    /**
     * Mirror of the SalesOrderService pattern: if an ACTIVE approval workflow
     * for WORK_ORDER matches the order's context, the WO goes to
     * PENDING_APPROVAL and an approval request is opened. Workflows are seeded
     * inactive, so this is a no-op until an admin activates one.
     */
    private WorkOrder applyApprovalWorkflowIfMatched(WorkOrder wo) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> context = Map.of(
                "workOrder.totalCost", wo.getTotalCost(),
                "workOrder.quantity", wo.getQuantityToProduce(),
                "workOrder.priority", wo.getPriority() != null ? wo.getPriority() : "NORMAL",
                "item.id", wo.getFinishedGoodId().toString());

        Optional<WorkflowDefinition> workflow =
                approvalWorkflowService.findMatchingWorkflow(orgId, "WORK_ORDER", context);
        if (workflow.isEmpty()) {
            return wo;
        }

        wo.setStatus("PENDING_APPROVAL");
        wo.setApprovalStatus("PENDING");
        wo = workOrderRepository.save(wo);
        approvalWorkflowService.requestApproval(
                orgId,
                workflow.get(),
                "WORK_ORDER",
                wo.getId(),
                "Work order " + wo.getWorkOrderNumber() + " requires approval before production",
                context);
        log.info("Work order {} routed to approval workflow {} for org {}",
                wo.getWorkOrderNumber(), workflow.get().getCode(), orgId);
        return wo;
    }

    private String normalizePriority(String priority, boolean defaultWhenBlank) {
        if (priority == null || priority.isBlank()) {
            if (defaultWhenBlank) {
                return "NORMAL";
            }
            throw new BusinessException("Priority is required",
                    "MFG_INVALID_PRIORITY", HttpStatus.BAD_REQUEST);
        }
        String normalized = priority.trim().toUpperCase();
        if (!VALID_PRIORITIES.contains(normalized)) {
            throw new BusinessException(
                    "Invalid priority '" + priority + "' — must be one of URGENT, HIGH, NORMAL, LOW",
                    "MFG_INVALID_PRIORITY", HttpStatus.BAD_REQUEST);
        }
        return normalized;
    }

    // ── Priority ─────────────────────────────────────────────────────

    @Transactional
    public WorkOrder updatePriority(UUID workOrderId, String priority) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if ("CANCELLED".equals(wo.getStatus())) {
            throw new BusinessException("Cannot change priority of a cancelled work order",
                    "MFG_ALREADY_CANCELLED", HttpStatus.BAD_REQUEST);
        }

        wo.setPriority(normalizePriority(priority, false));
        wo = workOrderRepository.save(wo);
        log.info("Work order {} priority set to {} for org {}",
                wo.getWorkOrderNumber(), wo.getPriority(), orgId);
        return wo;
    }

    // ── Clone ────────────────────────────────────────────────────────

    /**
     * Clones a work order into a fresh DRAFT: same item, quantity, warehouse,
     * BOM version, routing, backflush mode and lines — but zeroed
     * issued/produced quantities, a new WO number, and no journal or
     * sales-order references.
     */
    @Transactional
    public WorkOrder cloneWorkOrder(UUID workOrderId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder source = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        int nextNum = workOrderRepository.findMaxWorkOrderNumber(orgId) + 1;
        String woNumber = String.format("WO-%05d", nextNum);

        WorkOrder clone = WorkOrder.builder()
                .workOrderNumber(woNumber)
                .finishedGoodId(source.getFinishedGoodId())
                .warehouseId(source.getWarehouseId())
                .quantityToProduce(source.getQuantityToProduce())
                .plannedStartDate(source.getPlannedStartDate())
                .plannedEndDate(source.getPlannedEndDate())
                .directLaborCost(source.getDirectLaborCost())
                .overheadCost(source.getOverheadCost())
                .notes("Cloned from " + source.getWorkOrderNumber())
                .status("DRAFT")
                .backflushMode(source.isBackflushMode())
                .bomVersion(source.getBomVersion())
                .routingId(source.getRoutingId())
                .priority(source.getPriority() != null ? source.getPriority() : "NORMAL")
                .disassembly(source.isDisassembly())
                .lines(new ArrayList<>())
                .build();

        clone = workOrderRepository.save(clone);

        BigDecimal totalRmCost = BigDecimal.ZERO;
        for (WorkOrderLine line : source.getLines()) {
            if (line.isDeleted()) continue;

            BigDecimal lineCost = line.getUnitCost().multiply(line.getRequiredQty())
                    .setScale(2, RoundingMode.HALF_UP);
            WorkOrderLine newLine = WorkOrderLine.builder()
                    .workOrder(clone)
                    .itemId(line.getItemId())
                    .requiredQty(line.getRequiredQty())
                    .issuedQty(BigDecimal.ZERO)
                    .unitCost(line.getUnitCost())
                    .lineCost(lineCost)
                    .status("PENDING")
                    .build();
            clone.getLines().add(newLine);
            totalRmCost = totalRmCost.add(lineCost);
        }

        clone.setRawMaterialCost(totalRmCost);
        recalculateTotalCost(clone);

        clone = workOrderRepository.save(clone);
        clone = applyApprovalWorkflowIfMatched(clone);

        log.info("Work order {} cloned from {} for org {}",
                clone.getWorkOrderNumber(), source.getWorkOrderNumber(), orgId);
        return clone;
    }

    @Transactional(readOnly = true)
    public WorkOrder getWorkOrder(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", id));
    }

    /** Shop-floor lookup by the printed/scanned WO number. */
    @Transactional(readOnly = true)
    public WorkOrder getWorkOrderByNumber(String workOrderNumber) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return workOrderRepository
                .findByOrgIdAndWorkOrderNumberIgnoreCaseAndIsDeletedFalse(orgId, workOrderNumber)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderNumber));
    }

    @Transactional(readOnly = true)
    public Page<WorkOrder> listWorkOrders(String status, Pageable pageable) {
        return listWorkOrders(status, null, pageable);
    }

    @Transactional(readOnly = true)
    public Page<WorkOrder> listWorkOrders(String status, String priority, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String statusFilter = (status != null && !status.isBlank()) ? status : null;
        String priorityFilter = (priority != null && !priority.isBlank())
                ? normalizePriority(priority, false) : null;

        if (pageable.getSort().isUnsorted()) {
            // Default ordering: URGENT first, newest first within each band.
            return workOrderRepository.findForListPriorityFirst(
                    orgId, statusFilter, priorityFilter, pageable);
        }

        // Explicit sort requested by the caller — honour it as-is.
        if (statusFilter != null && priorityFilter != null) {
            return workOrderRepository.findByOrgIdAndStatusAndPriorityAndIsDeletedFalse(
                    orgId, statusFilter, priorityFilter, pageable);
        }
        if (priorityFilter != null) {
            return workOrderRepository.findByOrgIdAndPriorityAndIsDeletedFalse(orgId, priorityFilter, pageable);
        }
        if (statusFilter != null) {
            return workOrderRepository.findByOrgIdAndStatusAndIsDeletedFalse(orgId, statusFilter, pageable);
        }
        return workOrderRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
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
        Map<UUID, BigDecimal> scrapByChild = scrapPercentByChild(wo);
        BigDecimal actualRmCost = BigDecimal.ZERO;
        for (WorkOrderLine line : wo.getLines()) {
            if (line.isDeleted()) continue;

            // Inflate by the BOM line's scrap percent so the shop floor
            // receives enough material to cover expected process loss.
            BigDecimal scrapPercent = scrapByChild.getOrDefault(line.getItemId(), BigDecimal.ZERO);
            BigDecimal issueQty = line.getRequiredQty();
            if (scrapPercent.signum() > 0) {
                issueQty = issueQty
                        .multiply(BigDecimal.ONE.add(scrapPercent.divide(HUNDRED, 6, RoundingMode.HALF_UP)))
                        .setScale(4, RoundingMode.HALF_UP);
            }

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
                    "Production issue for " + wo.getWorkOrderNumber()
            ));

            line.setIssuedQty(issueQty);
            line.setStatus("ISSUED");
            BigDecimal lineCost = line.getUnitCost().multiply(line.getIssuedQty())
                    .setScale(2, RoundingMode.HALF_UP);
            line.setLineCost(lineCost);
            actualRmCost = actualRmCost.add(lineCost);
        }
        wo.setRawMaterialCost(actualRmCost);
    }

    /**
     * Map childItemId → scrap percent for the WO's BOM (version-aware).
     * Only entries with scrap > 0 are returned, so an empty/missing BOM
     * or a substituted line (whose item no longer matches a BOM child)
     * falls back to zero inflation — identical to the pre-scrap path.
     */
    private Map<UUID, BigDecimal> scrapPercentByChild(WorkOrder wo) {
        List<BomComponent> bom = wo.getBomVersion() != null
                ? bomComponentRepository
                        .findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                                wo.getOrgId(), wo.getFinishedGoodId(), wo.getBomVersion())
                : bomComponentRepository
                        .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(
                                wo.getOrgId(), wo.getFinishedGoodId());
        Map<UUID, BigDecimal> scrapByChild = new HashMap<>();
        for (BomComponent comp : bom) {
            if (comp.getScrapPercent() != null && comp.getScrapPercent().signum() > 0) {
                scrapByChild.put(comp.getChildItemId(), comp.getScrapPercent());
            }
        }
        return scrapByChild;
    }

    // ── Receive Finished Goods ───────────────────────────────────────

    @Transactional
    public WorkOrder receiveFinishedGoods(UUID workOrderId, BigDecimal quantityReceived) {
        return receiveFinishedGoods(workOrderId, quantityReceived, null, null);
    }

    /**
     * Receives finished goods and, when the FG item is batch-tracked,
     * assigns the produced quantity to a named batch (regulatory must-have
     * for pharma + food). The batch row is upserted on the natural key
     * (org, item, batch_number) so repeated receipts into the same batch
     * accumulate rather than duplicate.
     *
     * @param batchNumber required when the FG item has
     *                    {@code trackBatches=true}; rejected for items
     *                    that don't track batches to keep the ledger
     *                    consistent.
     * @param expiryDate  optional; only stored on a freshly-created batch
     *                    so concurrent receipts don't overwrite each
     *                    other's expiry.
     */
    @Transactional
    public WorkOrder receiveFinishedGoods(UUID workOrderId, BigDecimal quantityReceived,
                                          String batchNumber, LocalDate expiryDate) {
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

        // Co-products: each receives Q × quantityPerUnit, costed at
        // (total WO cost × costAllocationPercent/100) spread over its
        // planned quantity; the main FG keeps the remaining percentage.
        // With no co-products defined this block computes the exact
        // pre-existing fgUnitCost — byte-for-byte unchanged.
        List<BomCoProduct> coProducts = bomCoProductRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(
                        orgId, wo.getFinishedGoodId());

        BigDecimal fgUnitCost;
        if (coProducts.isEmpty()) {
            fgUnitCost = wo.getQuantityToProduce().compareTo(BigDecimal.ZERO) > 0
                    ? wo.getTotalCost().divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
        } else {
            BigDecimal allocatedPercent = coProducts.stream()
                    .map(cp -> cp.getCostAllocationPercent() != null
                            ? cp.getCostAllocationPercent() : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            BigDecimal mainPercent = HUNDRED.subtract(allocatedPercent);
            if (mainPercent.signum() < 0) mainPercent = BigDecimal.ZERO;
            fgUnitCost = wo.getQuantityToProduce().compareTo(BigDecimal.ZERO) > 0
                    ? wo.getTotalCost().multiply(mainPercent)
                            .divide(HUNDRED, 8, RoundingMode.HALF_UP)
                            .divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
        }

        UUID fgBatchId = resolveFgBatch(orgId, wo.getFinishedGoodId(),
                batchNumber, expiryDate, fgUnitCost);

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
                "Finished goods receipt for " + wo.getWorkOrderNumber(),
                fgBatchId
        ));

        // Wire RM↔FG traces so the batch-recall report can walk them.
        // Idempotent inside BatchTraceService — safe across partial receipts.
        if (fgBatchId != null && batchTraceService != null) {
            batchTraceService.linkTracesForFgReceipt(wo.getId(), fgBatchId, wo.getFinishedGoodId());
        }

        for (BomCoProduct cp : coProducts) {
            BigDecimal cpQty = quantityReceived.multiply(cp.getQuantityPerUnit())
                    .setScale(4, RoundingMode.HALF_UP);
            if (cpQty.signum() <= 0) continue;

            // Unit cost based on the PLANNED co-product output so partial
            // receipts carry a stable per-unit cost (mirrors fgUnitCost,
            // which divides by quantityToProduce).
            BigDecimal plannedCpQty = wo.getQuantityToProduce().multiply(cp.getQuantityPerUnit());
            BigDecimal allocPercent = cp.getCostAllocationPercent() != null
                    ? cp.getCostAllocationPercent() : BigDecimal.ZERO;
            BigDecimal cpUnitCost = plannedCpQty.signum() > 0
                    ? wo.getTotalCost().multiply(allocPercent)
                            .divide(HUNDRED, 8, RoundingMode.HALF_UP)
                            .divide(plannedCpQty, 4, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            inventoryService.recordMovement(new StockMovementRequest(
                    cp.getCoProductItemId(),
                    wo.getWarehouseId(),
                    MovementType.PRODUCTION_RECEIVE,
                    cpQty,
                    cpUnitCost,
                    LocalDate.now(),
                    ReferenceType.WORK_ORDER,
                    wo.getId(),
                    wo.getWorkOrderNumber(),
                    "Co-product receipt for " + wo.getWorkOrderNumber()
            ));
        }

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

    // ── FG batch assignment on receipt ───────────────────────────────

    /**
     * Resolves the batch id to stamp on the FG receive movement.
     *
     * <ul>
     *   <li>Item doesn't track batches + caller passed no batch number →
     *       {@code null} (legacy behaviour, byte-for-byte unchanged).</li>
     *   <li>Item doesn't track batches but caller insisted on a batch
     *       number → reject ({@code MFG_ITEM_NOT_BATCH_TRACKED}) so we
     *       don't silently lose data.</li>
     *   <li>Item tracks batches and caller supplied a number → upsert
     *       on the (org, item, batch_number) natural key. Repeated
     *       receipts into the same batch reuse the row.</li>
     *   <li>Item tracks batches but caller skipped the number → reject
     *       ({@code MFG_BATCH_REQUIRED}) so the FG ledger isn't left
     *       with un-traceable rows.</li>
     * </ul>
     */
    private UUID resolveFgBatch(UUID orgId, UUID fgItemId, String batchNumber,
                                LocalDate expiryDate, BigDecimal unitCost) {
        boolean supplied = batchNumber != null && !batchNumber.isBlank();
        // Common path (legacy + non-batch items + no batch number requested):
        // skip the item lookup entirely so the existing test fixtures stay
        // green and we don't add a DB hit to every receive call.
        if (!supplied) {
            Item fg = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId).orElse(null);
            if (fg != null && fg.isTrackBatches()) {
                throw new BusinessException(
                        "Batch number is required when receiving FG for a batch-tracked item",
                        "MFG_BATCH_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            return null;
        }
        Item fg = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", fgItemId));
        if (!fg.isTrackBatches()) {
            throw new BusinessException(
                    "Item " + fg.getName() + " does not track batches",
                    "MFG_ITEM_NOT_BATCH_TRACKED", HttpStatus.BAD_REQUEST);
        }

        String trimmed = batchNumber.trim();
        StockBatch batch = stockBatchRepository
                .findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse(orgId, fgItemId, trimmed)
                .orElseGet(() -> {
                    StockBatch fresh = StockBatch.builder()
                            .itemId(fgItemId)
                            .batchNumber(trimmed)
                            .manufacturingDate(LocalDate.now())
                            .expiryDate(expiryDate)
                            .unitCost(unitCost != null ? unitCost : BigDecimal.ZERO)
                            .active(true)
                            .build();
                    fresh.setOrgId(orgId);
                    return stockBatchRepository.save(fresh);
                });
        return batch.getId();
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

    // ── Auto-create WOs from reorder points ──────────────────────────

    /**
     * Auto-WO sweep (tracker #66). Walks every batch-balance row whose
     * on-hand quantity is at or below the item's reorder level, keeps
     * only COMPOSITE items (those we can manufacture), aggregates the
     * deficit across warehouses, and creates one DRAFT work order per
     * FG with the missing quantity. Idempotent — skips any FG that
     * already has an open DRAFT / PENDING_APPROVAL / IN_PROGRESS WO
     * so the cron can run every hour without piling up draft tickets.
     *
     * <p>Designed to be called by an MRP cron or by an admin "Replenish
     * now" button. The created WOs land in DRAFT so a planner reviews
     * BOMs / dates before issuing materials.
     *
     * @return list of newly-created DRAFT work orders
     */
    @Transactional
    public List<WorkOrder> autoCreateWorkOrdersFromReorder() {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Total on-hand per item across warehouses. The default
        // warehouse becomes the WO's home warehouse below.
        Map<UUID, BigDecimal> onHandByItem = new LinkedHashMap<>();
        Map<UUID, BigDecimal> reorderByItem = new HashMap<>();
        for (StockBalance b : stockBalanceRepository.findLowStock(orgId)) {
            onHandByItem.merge(b.getItemId(),
                    b.getQuantityOnHand() == null ? BigDecimal.ZERO : b.getQuantityOnHand(),
                    BigDecimal::add);
        }
        if (onHandByItem.isEmpty()) return List.of();

        UUID defaultWarehouseId = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .orElseThrow(() -> new BusinessException("No default warehouse configured",
                        "WAREHOUSE_NOT_FOUND", HttpStatus.BAD_REQUEST))
                .getId();

        List<WorkOrder> created = new ArrayList<>();
        List<String> openStatuses = List.of("DRAFT", "PENDING_APPROVAL", "IN_PROGRESS");

        for (Map.Entry<UUID, BigDecimal> entry : onHandByItem.entrySet()) {
            UUID itemId = entry.getKey();
            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId).orElse(null);
            // Only manufactured items qualify — purchased low-stock rows
            // belong on a purchase requisition, not a work order.
            if (item == null || item.getItemType() != ItemType.COMPOSITE) continue;

            // Skip if there's already an open WO for this FG so the
            // sweep is safe to run on a cron. A planner who needs more
            // can edit the existing draft instead of stacking new ones.
            if (workOrderRepository.existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse(
                    orgId, itemId, openStatuses)) {
                continue;
            }
            BigDecimal reorderLevel = item.getReorderLevel() != null
                    ? item.getReorderLevel() : BigDecimal.ZERO;
            reorderByItem.put(itemId, reorderLevel);
            BigDecimal deficit = reorderLevel.subtract(entry.getValue());
            if (deficit.signum() <= 0) continue;     // changed since the query
            BigDecimal qty = deficit.setScale(2, RoundingMode.HALF_UP);

            try {
                WorkOrder wo = createWorkOrder(itemId, defaultWarehouseId, qty,
                        LocalDate.now(), LocalDate.now().plusDays(7),
                        BigDecimal.ZERO, BigDecimal.ZERO,
                        "Auto-created from reorder sweep (on hand "
                                + entry.getValue() + " ≤ reorder " + reorderLevel + ")");
                created.add(wo);
            } catch (BusinessException ex) {
                // Composite item with no BOM, no default account, etc. —
                // log and continue so one bad item doesn't kill the sweep.
                log.warn("Skipped reorder WO for item {}: {}", itemId, ex.getMessage());
            }
        }

        log.info("Reorder sweep created {} draft work orders for org {}", created.size(), orgId);
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

    /**
     * Production summary for a creation-date period: WO counts by status,
     * completion rate, on-time %, planned vs produced quantities, average
     * yield % (of completed WOs) and scrap totals by reason code.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getProductionSummary(LocalDate fromDate, LocalDate toDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (fromDate == null || toDate == null || toDate.isBefore(fromDate)) {
            throw new BusinessException("Invalid date range — fromDate must be on or before toDate",
                    "MFG_INVALID_DATE_RANGE", HttpStatus.BAD_REQUEST);
        }

        Instant fromTs = fromDate.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toTs = toDate.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        List<WorkOrder> orders = workOrderRepository
                .findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        orgId, fromTs, toTs);

        Map<String, Long> statusCounts = new TreeMap<>();
        BigDecimal totalPlannedQty = BigDecimal.ZERO;
        BigDecimal totalProducedQty = BigDecimal.ZERO;
        BigDecimal yieldSum = BigDecimal.ZERO;
        int completedCount = 0;
        int onTimeMeasured = 0;
        int onTimeCount = 0;

        for (WorkOrder wo : orders) {
            statusCounts.merge(wo.getStatus(), 1L, Long::sum);
            totalPlannedQty = totalPlannedQty.add(wo.getQuantityToProduce());
            totalProducedQty = totalProducedQty.add(wo.getQuantityProduced());

            if ("COMPLETED".equals(wo.getStatus())) {
                completedCount++;
                if (wo.getQuantityToProduce().signum() > 0) {
                    yieldSum = yieldSum.add(wo.getQuantityProduced()
                            .divide(wo.getQuantityToProduce(), 4, RoundingMode.HALF_UP)
                            .multiply(HUNDRED));
                }
                if (wo.getPlannedEndDate() != null && wo.getActualEndDate() != null) {
                    onTimeMeasured++;
                    if (!wo.getActualEndDate().isAfter(wo.getPlannedEndDate())) {
                        onTimeCount++;
                    }
                }
            }
        }

        BigDecimal completionRate = orders.isEmpty() ? BigDecimal.ZERO
                : BigDecimal.valueOf(completedCount)
                        .divide(BigDecimal.valueOf(orders.size()), 4, RoundingMode.HALF_UP)
                        .multiply(HUNDRED).setScale(2, RoundingMode.HALF_UP);
        BigDecimal onTimePercent = onTimeMeasured == 0 ? BigDecimal.ZERO
                : BigDecimal.valueOf(onTimeCount)
                        .divide(BigDecimal.valueOf(onTimeMeasured), 4, RoundingMode.HALF_UP)
                        .multiply(HUNDRED).setScale(2, RoundingMode.HALF_UP);
        BigDecimal averageYieldPercent = completedCount == 0 ? BigDecimal.ZERO
                : yieldSum.divide(BigDecimal.valueOf(completedCount), 2, RoundingMode.HALF_UP);

        // Scrap by reason code, for scrap recorded inside the period
        List<ProductionScrap> scrapRows = productionScrapRepository
                .findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                        orgId, fromTs, toTs);

        Map<UUID, Map<String, Object>> scrapByReason = new LinkedHashMap<>();
        BigDecimal totalScrapQty = BigDecimal.ZERO;
        BigDecimal totalScrapCost = BigDecimal.ZERO;
        for (ProductionScrap scrap : scrapRows) {
            totalScrapQty = totalScrapQty.add(scrap.getScrapQty());
            totalScrapCost = totalScrapCost.add(scrap.getScrapCost());

            Map<String, Object> bucket = scrapByReason.computeIfAbsent(scrap.getReasonCodeId(), reasonId -> {
                Map<String, Object> row = new HashMap<>();
                row.put("reasonCodeId", reasonId);
                String code = "UNSPECIFIED";
                String description = null;
                if (reasonId != null) {
                    ScrapReasonCode reason = scrapReasonCodeRepository
                            .findByIdAndOrgIdAndIsDeletedFalse(reasonId, orgId).orElse(null);
                    if (reason != null) {
                        code = reason.getCode();
                        description = reason.getDescription();
                    }
                }
                row.put("reasonCode", code);
                row.put("description", description);
                row.put("totalQty", BigDecimal.ZERO);
                row.put("totalCost", BigDecimal.ZERO);
                return row;
            });
            bucket.put("totalQty", ((BigDecimal) bucket.get("totalQty")).add(scrap.getScrapQty()));
            bucket.put("totalCost", ((BigDecimal) bucket.get("totalCost")).add(scrap.getScrapCost()));
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("fromDate", fromDate);
        result.put("toDate", toDate);
        result.put("totalWorkOrders", orders.size());
        result.put("statusCounts", statusCounts);
        result.put("completedCount", completedCount);
        result.put("completionRate", completionRate);
        result.put("onTimePercent", onTimePercent);
        result.put("onTimeMeasuredCount", onTimeMeasured);
        result.put("totalPlannedQty", totalPlannedQty);
        result.put("totalProducedQty", totalProducedQty);
        result.put("averageYieldPercent", averageYieldPercent);
        result.put("totalScrapQty", totalScrapQty);
        result.put("totalScrapCost", totalScrapCost);
        result.put("scrapByReason", new ArrayList<>(scrapByReason.values()));
        return result;
    }

    /**
     * Work-order profitability report (tracker #53). For every completed
     * WO whose finished good was sold via a linked Sales Order, joins the
     * SO line's unit rate with the {@link ProductionCostSummary}'s
     * actual total to compute revenue / cost / profit / margin per WO.
     * Worst-margin first so loss-making WOs surface to the top.
     */
    public List<Map<String, Object>> workOrderProfitability(LocalDate fromDate, LocalDate toDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (fromDate == null || toDate == null || toDate.isBefore(fromDate)) {
            throw new BusinessException("Invalid date range — fromDate must be on or before toDate",
                    "MFG_INVALID_DATE_RANGE", HttpStatus.BAD_REQUEST);
        }
        Instant fromTs = fromDate.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toTs = toDate.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        List<WorkOrder> orders = workOrderRepository
                .findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        orgId, fromTs, toTs);

        List<Map<String, Object>> rows = new ArrayList<>();
        for (WorkOrder wo : orders) {
            if (!"COMPLETED".equals(wo.getStatus())) continue;

            BigDecimal cost = costSummaryRepository
                    .findByWorkOrderIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId)
                    .map(ProductionCostSummary::getActualTotal)
                    .orElse(BigDecimal.ZERO);
            if (cost == null) cost = BigDecimal.ZERO;

            BigDecimal revenue = BigDecimal.ZERO;
            String revenueSource = "NONE";
            if (wo.getSalesOrderId() != null) {
                SalesOrder so = salesOrderRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(wo.getSalesOrderId(), orgId)
                        .orElse(null);
                if (so != null) {
                    for (SalesOrderLine line : so.getLines()) {
                        if (line.getItemId() == null) continue;
                        if (!line.getItemId().equals(wo.getFinishedGoodId())) continue;
                        BigDecimal rate = line.getRate() != null ? line.getRate() : BigDecimal.ZERO;
                        revenue = revenue.add(rate.multiply(wo.getQuantityProduced())
                                .setScale(2, RoundingMode.HALF_UP));
                    }
                    if (revenue.signum() > 0) revenueSource = "SO_LINE";
                }
            }

            BigDecimal profit = revenue.subtract(cost).setScale(2, RoundingMode.HALF_UP);
            BigDecimal margin = revenue.signum() > 0
                    ? profit.multiply(HUNDRED).divide(revenue, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("workOrderId", wo.getId());
            row.put("workOrderNumber", wo.getWorkOrderNumber());
            row.put("finishedGoodId", wo.getFinishedGoodId());
            row.put("quantityProduced", wo.getQuantityProduced());
            row.put("revenue", revenue);
            row.put("cost", cost);
            row.put("profit", profit);
            row.put("marginPercent", margin);
            row.put("revenueSource", revenueSource);
            row.put("salesOrderId", wo.getSalesOrderId());
            row.put("completedOn", wo.getActualEndDate());
            rows.add(row);
        }
        // Worst-margin first so loss-making WOs surface to the top.
        rows.sort((a, b) -> ((BigDecimal) a.get("marginPercent"))
                .compareTo((BigDecimal) b.get("marginPercent")));
        return rows;
    }

    /**
     * Scrap rate dashboard (tracker #54). Aggregates production scrap in
     * the window by both reason code (sorted by cost desc) and finished-
     * good item (sorted by scrap rate desc, so the worst products bubble
     * up). Rate uses scrapQty / (producedQty + scrapQty) so it stays
     * between 0 and 100% even when every produced unit was scrapped.
     */
    public Map<String, Object> scrapRateDashboard(LocalDate fromDate, LocalDate toDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (fromDate == null || toDate == null || toDate.isBefore(fromDate)) {
            throw new BusinessException("Invalid date range — fromDate must be on or before toDate",
                    "MFG_INVALID_DATE_RANGE", HttpStatus.BAD_REQUEST);
        }
        Instant fromTs = fromDate.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toTs = toDate.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        // Produced qty per FG item — denominator for the per-item scrap
        // rate. Pulled from completed WOs whose finished_good_id matches.
        Map<UUID, BigDecimal> producedByItem = new HashMap<>();
        for (WorkOrder wo : workOrderRepository
                .findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        orgId, fromTs, toTs)) {
            if (!"COMPLETED".equals(wo.getStatus())) continue;
            producedByItem.merge(wo.getFinishedGoodId(),
                    wo.getQuantityProduced(), BigDecimal::add);
        }

        List<ProductionScrap> scrapRows = productionScrapRepository
                .findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                        orgId, fromTs, toTs);

        Map<UUID, Map<String, Object>> byReason = new LinkedHashMap<>();
        Map<UUID, Map<String, Object>> byItem = new LinkedHashMap<>();
        BigDecimal totalScrapQty = BigDecimal.ZERO;
        BigDecimal totalScrapCost = BigDecimal.ZERO;
        for (ProductionScrap s : scrapRows) {
            totalScrapQty = totalScrapQty.add(s.getScrapQty());
            totalScrapCost = totalScrapCost.add(s.getScrapCost());

            Map<String, Object> rb = byReason.computeIfAbsent(s.getReasonCodeId(), reasonId -> {
                Map<String, Object> r = new LinkedHashMap<>();
                String code = "UNSPECIFIED";
                if (reasonId != null) {
                    ScrapReasonCode rc = scrapReasonCodeRepository
                            .findByIdAndOrgIdAndIsDeletedFalse(reasonId, orgId).orElse(null);
                    if (rc != null) code = rc.getCode();
                }
                r.put("reasonCodeId", reasonId);
                r.put("reasonCode", code);
                r.put("scrapQty", BigDecimal.ZERO);
                r.put("scrapCost", BigDecimal.ZERO);
                return r;
            });
            rb.put("scrapQty", ((BigDecimal) rb.get("scrapQty")).add(s.getScrapQty()));
            rb.put("scrapCost", ((BigDecimal) rb.get("scrapCost")).add(s.getScrapCost()));

            Map<String, Object> ri = byItem.computeIfAbsent(s.getItemId(), itemId -> {
                Map<String, Object> r = new LinkedHashMap<>();
                String name = null;
                if (itemId != null) {
                    Item it = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId).orElse(null);
                    if (it != null) name = it.getName();
                }
                r.put("itemId", itemId);
                r.put("itemName", name);
                r.put("scrapQty", BigDecimal.ZERO);
                r.put("scrapCost", BigDecimal.ZERO);
                return r;
            });
            ri.put("scrapQty", ((BigDecimal) ri.get("scrapQty")).add(s.getScrapQty()));
            ri.put("scrapCost", ((BigDecimal) ri.get("scrapCost")).add(s.getScrapCost()));
        }

        for (Map.Entry<UUID, Map<String, Object>> entry : byItem.entrySet()) {
            BigDecimal scrapQty = (BigDecimal) entry.getValue().get("scrapQty");
            BigDecimal produced = producedByItem.getOrDefault(entry.getKey(), BigDecimal.ZERO);
            BigDecimal denom = produced.add(scrapQty);
            BigDecimal rate = denom.signum() > 0
                    ? scrapQty.multiply(HUNDRED).divide(denom, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
            entry.getValue().put("producedQty", produced);
            entry.getValue().put("scrapRatePercent", rate);
        }
        List<Map<String, Object>> itemRows = new ArrayList<>(byItem.values());
        itemRows.sort((a, b) -> ((BigDecimal) b.get("scrapRatePercent"))
                .compareTo((BigDecimal) a.get("scrapRatePercent")));
        List<Map<String, Object>> reasonRows = new ArrayList<>(byReason.values());
        reasonRows.sort((a, b) -> ((BigDecimal) b.get("scrapCost"))
                .compareTo((BigDecimal) a.get("scrapCost")));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("fromDate", fromDate);
        out.put("toDate", toDate);
        out.put("totalScrapQty", totalScrapQty);
        out.put("totalScrapCost", totalScrapCost);
        out.put("byItem", itemRows);
        out.put("byReason", reasonRows);
        return out;
    }

    /**
     * Daily throughput trend for charting on the production dashboard —
     * one bucket per day in the inclusive window with WOs started,
     * completed, quantity produced (sum across that day's completions),
     * and scrap qty / cost. Days with zero activity still appear so the
     * chart shows continuous data.
     */
    public List<Map<String, Object>> productionTrends(LocalDate fromDate, LocalDate toDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (fromDate == null || toDate == null || toDate.isBefore(fromDate)) {
            throw new BusinessException("Invalid date range — fromDate must be on or before toDate",
                    "MFG_INVALID_DATE_RANGE", HttpStatus.BAD_REQUEST);
        }

        // Pull every WO that could fall in the window — created OR started
        // OR completed within it. Cheapest is to load by createdAt window
        // padded back so we cover late-completing orders, then filter
        // per-day on the actual start/end dates.
        Instant fromTs = fromDate.minusDays(180).atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant toTs = toDate.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        List<WorkOrder> orders = workOrderRepository
                .findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        orgId, fromTs, toTs);

        Map<LocalDate, Map<String, Object>> byDay = new TreeMap<>();
        for (LocalDate d = fromDate; !d.isAfter(toDate); d = d.plusDays(1)) {
            Map<String, Object> bucket = new LinkedHashMap<>();
            bucket.put("date", d);
            bucket.put("woStarted", 0L);
            bucket.put("woCompleted", 0L);
            bucket.put("quantityProduced", BigDecimal.ZERO);
            bucket.put("scrapQty", BigDecimal.ZERO);
            bucket.put("scrapCost", BigDecimal.ZERO);
            byDay.put(d, bucket);
        }

        for (WorkOrder wo : orders) {
            LocalDate start = wo.getActualStartDate();
            if (start != null && !start.isBefore(fromDate) && !start.isAfter(toDate)) {
                Map<String, Object> b = byDay.get(start);
                b.put("woStarted", (long) b.get("woStarted") + 1L);
            }
            LocalDate end = wo.getActualEndDate();
            if (end != null && !end.isBefore(fromDate) && !end.isAfter(toDate)
                    && "COMPLETED".equals(wo.getStatus())) {
                Map<String, Object> b = byDay.get(end);
                b.put("woCompleted", (long) b.get("woCompleted") + 1L);
                b.put("quantityProduced",
                        ((BigDecimal) b.get("quantityProduced")).add(wo.getQuantityProduced()));
            }
        }

        Instant scrapFrom = fromDate.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant scrapTo = toDate.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        for (ProductionScrap scrap : productionScrapRepository
                .findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                        orgId, scrapFrom, scrapTo)) {
            LocalDate day = scrap.getScrappedAt().atZone(ZoneOffset.UTC).toLocalDate();
            Map<String, Object> b = byDay.get(day);
            if (b == null) continue;
            b.put("scrapQty", ((BigDecimal) b.get("scrapQty")).add(scrap.getScrapQty()));
            b.put("scrapCost", ((BigDecimal) b.get("scrapCost")).add(scrap.getScrapCost()));
        }

        return new ArrayList<>(byDay.values());
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

    /**
     * BOM version diff (tracker #41) — compares two snapshots of the same
     * parent's BOM and groups the differences into ADDED / REMOVED /
     * CHANGED. Components matched by child item id.
     *
     * <p>"CHANGED" picks up rows whose quantity OR scrap percent moved.
     * Both numbers are returned so the UI can show "5 → 7 (+40%)" style
     * deltas. Item names are resolved once per child so a 50-line BOM
     * doesn't fan out into 50 lookups inside the comparator.
     *
     * <p>Returns ordered lists keyed by section so the response is
     * directly renderable as a single screen — the front-end doesn't
     * need to re-sort.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> diffBomVersions(UUID parentItemId, int fromVersion, int toVersion) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (fromVersion == toVersion) {
            throw new BusinessException("Choose two different versions to diff",
                    "BOM_DIFF_SAME_VERSION", HttpStatus.BAD_REQUEST);
        }

        List<BomComponent> fromComps = bomComponentRepository
                .findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                        orgId, parentItemId, fromVersion);
        List<BomComponent> toComps = bomComponentRepository
                .findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                        orgId, parentItemId, toVersion);
        if (fromComps.isEmpty() && toComps.isEmpty()) {
            throw new BusinessException(
                    "Neither version " + fromVersion + " nor " + toVersion + " has any components",
                    "BOM_DIFF_VERSIONS_EMPTY", HttpStatus.NOT_FOUND);
        }

        Map<UUID, BomComponent> fromByChild = fromComps.stream()
                .collect(Collectors.toMap(BomComponent::getChildItemId, c -> c, (a, b) -> a, LinkedHashMap::new));
        Map<UUID, BomComponent> toByChild = toComps.stream()
                .collect(Collectors.toMap(BomComponent::getChildItemId, c -> c, (a, b) -> a, LinkedHashMap::new));

        // Resolve every child item name in one pass — single map shared
        // by the three sections so we don't hit itemRepository per row.
        Set<UUID> allChildIds = new HashSet<>();
        allChildIds.addAll(fromByChild.keySet());
        allChildIds.addAll(toByChild.keySet());
        Map<UUID, String> nameByChild = new HashMap<>();
        for (UUID childId : allChildIds) {
            itemRepository.findByIdAndOrgIdAndIsDeletedFalse(childId, orgId)
                    .ifPresent(it -> nameByChild.put(childId, it.getName()));
        }

        List<Map<String, Object>> added = new ArrayList<>();
        List<Map<String, Object>> removed = new ArrayList<>();
        List<Map<String, Object>> changed = new ArrayList<>();

        for (Map.Entry<UUID, BomComponent> e : toByChild.entrySet()) {
            UUID childId = e.getKey();
            BomComponent t = e.getValue();
            BomComponent f = fromByChild.get(childId);
            if (f == null) {
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("childItemId", childId);
                row.put("childItemName", nameByChild.get(childId));
                row.put("toQty", t.getQuantity());
                row.put("toScrapPercent", t.getScrapPercent());
                added.add(row);
            } else {
                BigDecimal fq = nz(f.getQuantity());
                BigDecimal tq = nz(t.getQuantity());
                BigDecimal fs = nz(f.getScrapPercent());
                BigDecimal ts = nz(t.getScrapPercent());
                if (fq.compareTo(tq) != 0 || fs.compareTo(ts) != 0) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    row.put("childItemId", childId);
                    row.put("childItemName", nameByChild.get(childId));
                    row.put("fromQty", fq);
                    row.put("toQty", tq);
                    row.put("qtyDelta", tq.subtract(fq));
                    row.put("fromScrapPercent", fs);
                    row.put("toScrapPercent", ts);
                    changed.add(row);
                }
            }
        }
        for (Map.Entry<UUID, BomComponent> e : fromByChild.entrySet()) {
            if (toByChild.containsKey(e.getKey())) continue;
            BomComponent f = e.getValue();
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("childItemId", e.getKey());
            row.put("childItemName", nameByChild.get(e.getKey()));
            row.put("fromQty", f.getQuantity());
            row.put("fromScrapPercent", f.getScrapPercent());
            removed.add(row);
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("parentItemId", parentItemId);
        out.put("fromVersion", fromVersion);
        out.put("toVersion", toVersion);
        out.put("added", added);
        out.put("removed", removed);
        out.put("changed", changed);
        out.put("addedCount", added.size());
        out.put("removedCount", removed.size());
        out.put("changedCount", changed.size());
        out.put("unchangedCount", toByChild.size() - added.size() - changed.size());
        return out;
    }

    private static BigDecimal nz(BigDecimal v) { return v == null ? BigDecimal.ZERO : v; }

    // ── BOM Alternates (substitute materials) ────────────────────────

    @Transactional
    public BomAlternate addBomAlternate(UUID bomComponentId, UUID alternateItemId,
                                        Integer priority, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();

        BomComponent comp = bomComponentRepository
                .findByIdAndOrgIdAndIsDeletedFalse(bomComponentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("BomComponent", bomComponentId));

        Item alternate = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(alternateItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", alternateItemId));

        if (alternateItemId.equals(comp.getChildItemId())) {
            throw new BusinessException(
                    "Alternate item is the same as the BOM line's primary component",
                    "MFG_ALTERNATE_SAME_AS_PRIMARY", HttpStatus.BAD_REQUEST);
        }

        if (bomAlternateRepository.existsByOrgIdAndBomComponentIdAndAlternateItemIdAndIsDeletedFalse(
                orgId, bomComponentId, alternateItemId)) {
            throw new BusinessException(
                    "Item " + alternate.getSku() + " is already registered as an alternate for this BOM line",
                    "MFG_ALTERNATE_DUPLICATE", HttpStatus.CONFLICT);
        }

        BomAlternate row = BomAlternate.builder()
                .bomComponentId(bomComponentId)
                .alternateItemId(alternateItemId)
                .priority(priority != null ? priority : 1)
                .notes(notes)
                .build();
        row = bomAlternateRepository.save(row);

        log.info("BOM alternate {} registered for component {} (org {})",
                alternate.getSku(), bomComponentId, orgId);
        return row;
    }

    @Transactional(readOnly = true)
    public List<BomAlternate> listBomAlternates(UUID bomComponentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        bomComponentRepository.findByIdAndOrgIdAndIsDeletedFalse(bomComponentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("BomComponent", bomComponentId));
        return bomAlternateRepository
                .findByOrgIdAndBomComponentIdAndIsDeletedFalseOrderByPriorityAsc(orgId, bomComponentId);
    }

    @Transactional
    public void deleteBomAlternate(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BomAlternate row = bomAlternateRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BomAlternate", id));
        row.setDeleted(true);
        bomAlternateRepository.save(row);
    }

    /**
     * Replace a DRAFT work-order line's component with one of the
     * registered alternates for the matching BOM line. Quantity stays
     * the same (alternates substitute 1:1); unit cost re-prices from
     * the alternate's purchase price and the WO totals are recomputed.
     */
    @Transactional
    public WorkOrder substituteWorkOrderLine(UUID workOrderId, UUID lineId, UUID alternateItemId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        WorkOrder wo = workOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(workOrderId, orgId)
                .orElseThrow(() -> BusinessException.notFound("WorkOrder", workOrderId));

        if (!"DRAFT".equals(wo.getStatus())) {
            throw new BusinessException(
                    "Components can only be substituted while the work order is DRAFT, current: " + wo.getStatus(),
                    "MFG_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        WorkOrderLine line = wo.getLines().stream()
                .filter(l -> !l.isDeleted() && lineId.equals(l.getId()))
                .findFirst()
                .orElseThrow(() -> BusinessException.notFound("WorkOrderLine", lineId));

        // Find the BOM line this WO line was built from (version-aware).
        List<BomComponent> bom = wo.getBomVersion() != null
                ? bomComponentRepository
                        .findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                                orgId, wo.getFinishedGoodId(), wo.getBomVersion())
                : bomComponentRepository
                        .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(
                                orgId, wo.getFinishedGoodId());
        BomComponent comp = bom.stream()
                .filter(c -> c.getChildItemId().equals(line.getItemId()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(
                        "Work order line item does not match any BOM component of the finished good",
                        "MFG_BOM_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST));

        if (!bomAlternateRepository.existsByOrgIdAndBomComponentIdAndAlternateItemIdAndIsDeletedFalse(
                orgId, comp.getId(), alternateItemId)) {
            throw new BusinessException(
                    "Item is not a registered alternate for this BOM component",
                    "MFG_ALTERNATE_NOT_REGISTERED", HttpStatus.BAD_REQUEST);
        }

        Item alternate = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(alternateItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", alternateItemId));

        line.setItemId(alternateItemId);
        BigDecimal unitCost = alternate.getPurchasePrice() != null
                ? alternate.getPurchasePrice() : BigDecimal.ZERO;
        line.setUnitCost(unitCost);
        line.setLineCost(unitCost.multiply(line.getRequiredQty()).setScale(2, RoundingMode.HALF_UP));

        BigDecimal totalRmCost = BigDecimal.ZERO;
        for (WorkOrderLine l : wo.getLines()) {
            if (l.isDeleted()) continue;
            totalRmCost = totalRmCost.add(l.getLineCost());
        }
        wo.setRawMaterialCost(totalRmCost);
        recalculateTotalCost(wo);

        wo = workOrderRepository.save(wo);
        log.info("Work order {} line {} substituted with alternate {} for org {}",
                wo.getWorkOrderNumber(), lineId, alternate.getSku(), orgId);
        return wo;
    }

    // ── Co-products / By-products ────────────────────────────────────

    @Transactional
    public BomCoProduct addCoProduct(UUID parentItemId, UUID coProductItemId,
                                     BigDecimal quantityPerUnit, BigDecimal costAllocationPercent) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Item parent = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(parentItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", parentItemId));
        if (parent.getItemType() != ItemType.COMPOSITE) {
            throw new BusinessException(
                    "Co-products can only be defined on COMPOSITE items",
                    "MFG_NOT_COMPOSITE", HttpStatus.BAD_REQUEST);
        }

        if (parentItemId.equals(coProductItemId)) {
            throw new BusinessException(
                    "An item cannot be its own co-product",
                    "MFG_CO_PRODUCT_SELF", HttpStatus.BAD_REQUEST);
        }

        itemRepository.findByIdAndOrgIdAndIsDeletedFalse(coProductItemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", coProductItemId));

        if (quantityPerUnit == null || quantityPerUnit.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(
                    "Co-product quantity per unit must be positive",
                    "MFG_INVALID_QUANTITY", HttpStatus.BAD_REQUEST);
        }

        BigDecimal allocPercent = costAllocationPercent != null ? costAllocationPercent : BigDecimal.ZERO;
        if (allocPercent.signum() < 0) {
            throw new BusinessException(
                    "Cost allocation percent cannot be negative",
                    "MFG_CO_PRODUCT_PERCENT_INVALID", HttpStatus.BAD_REQUEST);
        }

        if (bomCoProductRepository.existsByOrgIdAndParentItemIdAndCoProductItemIdAndIsDeletedFalse(
                orgId, parentItemId, coProductItemId)) {
            throw new BusinessException(
                    "This co-product is already defined for the item — delete and re-add to change it",
                    "MFG_CO_PRODUCT_DUPLICATE", HttpStatus.CONFLICT);
        }

        BigDecimal existingAllocation = bomCoProductRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId)
                .stream()
                .map(cp -> cp.getCostAllocationPercent() != null
                        ? cp.getCostAllocationPercent() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (existingAllocation.add(allocPercent).compareTo(HUNDRED) > 0) {
            throw new BusinessException(
                    "Total co-product cost allocation would exceed 100% (existing: "
                            + existingAllocation + "%, adding: " + allocPercent + "%)",
                    "MFG_CO_PRODUCT_ALLOCATION_EXCEEDED", HttpStatus.BAD_REQUEST);
        }

        BomCoProduct row = BomCoProduct.builder()
                .parentItemId(parentItemId)
                .coProductItemId(coProductItemId)
                .quantityPerUnit(quantityPerUnit)
                .costAllocationPercent(allocPercent)
                .build();
        row = bomCoProductRepository.save(row);

        log.info("Co-product {} ({}× per unit, {}% cost) defined for item {} (org {})",
                coProductItemId, quantityPerUnit, allocPercent, parent.getSku(), orgId);
        return row;
    }

    @Transactional(readOnly = true)
    public List<BomCoProduct> listCoProducts(UUID parentItemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return bomCoProductRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);
    }

    @Transactional
    public void deleteCoProduct(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BomCoProduct row = bomCoProductRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BomCoProduct", id));
        row.setDeleted(true);
        bomCoProductRepository.save(row);
    }

    // ── BOM Cost Roll-up ─────────────────────────────────────────────

    /**
     * Recursive cost roll-up through every BOM level. Leaf items are
     * costed at their purchase price; composite children are costed
     * from their own components. Each level's quantity is inflated by
     * the BOM line's scrap percent, so the roll-up reflects what
     * production will actually consume.
     */
    @Transactional(readOnly = true)
    public Map<String, Object> getBomCostRollup(UUID itemId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Item root = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", itemId));

        java.util.Set<UUID> visiting = new java.util.HashSet<>();
        visiting.add(itemId);
        List<Map<String, Object>> children = rollupChildren(orgId, itemId, visiting);

        BigDecimal total = children.stream()
                .map(c -> (BigDecimal) c.get("extendedCost"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Object> result = new HashMap<>();
        result.put("itemId", itemId);
        result.put("sku", root.getSku());
        result.put("name", root.getName());
        result.put("totalCost", total);
        result.put("children", children);
        return result;
    }

    private List<Map<String, Object>> rollupChildren(UUID orgId, UUID parentItemId,
                                                     java.util.Set<UUID> visiting) {
        List<BomComponent> bom = bomComponentRepository
                .findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, parentItemId);

        List<Map<String, Object>> nodes = new ArrayList<>();
        for (BomComponent comp : bom) {
            Item child = itemRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(comp.getChildItemId(), orgId)
                    .orElse(null);
            if (child == null) continue;

            BigDecimal scrapPercent = comp.getScrapPercent() != null
                    ? comp.getScrapPercent() : BigDecimal.ZERO;
            BigDecimal effectiveQty = comp.getQuantity();
            if (scrapPercent.signum() > 0) {
                effectiveQty = effectiveQty
                        .multiply(BigDecimal.ONE.add(scrapPercent.divide(HUNDRED, 6, RoundingMode.HALF_UP)))
                        .setScale(4, RoundingMode.HALF_UP);
            }

            List<Map<String, Object>> grandChildren = List.of();
            BigDecimal unitCost;
            if (child.getItemType() == ItemType.COMPOSITE) {
                if (!visiting.add(child.getId())) {
                    throw new BusinessException(
                            "BOM cycle detected at item " + child.getSku(),
                            "BOM_CYCLE_DETECTED", HttpStatus.CONFLICT);
                }
                grandChildren = rollupChildren(orgId, child.getId(), visiting);
                visiting.remove(child.getId());
            }
            if (!grandChildren.isEmpty()) {
                // Cost of one unit of the composite child = sum of its
                // own component extended costs.
                unitCost = grandChildren.stream()
                        .map(c -> (BigDecimal) c.get("extendedCost"))
                        .reduce(BigDecimal.ZERO, BigDecimal::add);
            } else {
                unitCost = child.getPurchasePrice() != null
                        ? child.getPurchasePrice() : BigDecimal.ZERO;
            }

            BigDecimal extendedCost = unitCost.multiply(effectiveQty)
                    .setScale(2, RoundingMode.HALF_UP);

            Map<String, Object> node = new HashMap<>();
            node.put("itemId", child.getId());
            node.put("sku", child.getSku());
            node.put("name", child.getName());
            node.put("quantity", comp.getQuantity());
            node.put("scrapPercent", scrapPercent);
            node.put("effectiveQuantity", effectiveQty);
            node.put("unitCost", unitCost);
            node.put("extendedCost", extendedCost);
            node.put("phantom", child.isPhantom());
            node.put("children", grandChildren);
            nodes.add(node);
        }
        return nodes;
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
