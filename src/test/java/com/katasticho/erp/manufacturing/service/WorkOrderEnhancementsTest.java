package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.accounting.posting.ManufacturingWipPostingRule;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.BomAlternateRepository;
import com.katasticho.erp.inventory.repository.BomCoProductRepository;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
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
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkOrderEnhancementsTest {

    @Mock private WorkOrderRepository workOrderRepo;
    @Mock private WorkOrderLineRepository workOrderLineRepo;
    @Mock private BomComponentRepository bomComponentRepo;
    @Mock private ItemRepository itemRepo;
    @Mock private InventoryService inventoryService;
    @Mock private SalesOrderRepository salesOrderRepo;
    @Mock private WarehouseRepository warehouseRepo;
    @Mock private JournalService journalService;
    @Mock private ManufacturingWipPostingRule wipPostingRule;
    @Mock private ProductionCostSummaryRepository costSummaryRepo;
    @Mock private BomAlternateRepository bomAlternateRepo;
    @Mock private BomCoProductRepository bomCoProductRepo;
    @Mock private ApprovalWorkflowService approvalWorkflowService;
    @Mock private ProductionScrapRepository productionScrapRepo;
    @Mock private ScrapReasonCodeRepository scrapReasonCodeRepo;

    private ManufacturingService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID warehouseId = UUID.randomUUID();
    private final UUID fgItemId = UUID.randomUUID();
    private final UUID rmItemId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ManufacturingService(
                workOrderRepo, workOrderLineRepo, bomComponentRepo, itemRepo, inventoryService,
                salesOrderRepo, warehouseRepo, journalService, wipPostingRule, costSummaryRepo,
                bomAlternateRepo, bomCoProductRepo, approvalWorkflowService,
                productionScrapRepo, scrapReasonCodeRepo, null, null, null);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Priority ──────────────────────────────────────────────────────

    @Test
    void createWorkOrder_withPriority_setsNormalizedPriority() {
        stubHappyCreate();

        WorkOrder result = service.createWorkOrder(
                fgItemId, warehouseId, BigDecimal.TEN,
                null, null, null, null, "Urgent order",
                false, null, false, "urgent");

        assertEquals("URGENT", result.getPriority());
        assertEquals("DRAFT", result.getStatus());
    }

    @Test
    void createWorkOrder_noPriority_defaultsToNormal() {
        stubHappyCreate();

        WorkOrder result = service.createWorkOrder(
                fgItemId, warehouseId, BigDecimal.TEN,
                null, null, null, null, "Test WO");

        assertEquals("NORMAL", result.getPriority());
    }

    @Test
    void createWorkOrder_invalidPriority_throws() {
        Item fg = buildCompositeItem();
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(buildBomComponent()));
        when(bomComponentRepo.findMaxVersion(orgId, fgItemId)).thenReturn(1);
        when(workOrderRepo.findMaxWorkOrderNumber(orgId)).thenReturn(0);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createWorkOrder(fgItemId, warehouseId, BigDecimal.TEN,
                        null, null, null, null, null, false, null, false, "ASAP"));
        assertEquals("MFG_INVALID_PRIORITY", ex.getErrorCode());
        verify(workOrderRepo, never()).save(any());
    }

    @Test
    void updatePriority_nonCancelledOrder_updates() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.updatePriority(wo.getId(), "high");

        assertEquals("HIGH", result.getPriority());
        verify(workOrderRepo).save(wo);
    }

    @Test
    void updatePriority_cancelledOrder_throws() {
        WorkOrder wo = createTestWorkOrder("CANCELLED");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updatePriority(wo.getId(), "HIGH"));
        assertEquals("MFG_ALREADY_CANCELLED", ex.getErrorCode());
        verify(workOrderRepo, never()).save(any());
    }

    @Test
    void updatePriority_invalidValue_throws() {
        WorkOrder wo = createTestWorkOrder("DRAFT");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updatePriority(wo.getId(), "WHENEVER"));
        assertEquals("MFG_INVALID_PRIORITY", ex.getErrorCode());
    }

    @Test
    void listWorkOrders_noExplicitSort_usesPriorityFirstOrdering() {
        Pageable unsorted = PageRequest.of(0, 20);
        when(workOrderRepo.findForListPriorityFirst(orgId, null, "HIGH", unsorted))
                .thenReturn(Page.empty());

        service.listWorkOrders(null, "high", unsorted);

        verify(workOrderRepo).findForListPriorityFirst(orgId, null, "HIGH", unsorted);
    }

    @Test
    void listWorkOrders_explicitSort_honoursCallerSort() {
        Pageable sorted = PageRequest.of(0, 20, Sort.by("createdAt").ascending());
        when(workOrderRepo.findByOrgIdAndStatusAndPriorityAndIsDeletedFalse(
                orgId, "DRAFT", "URGENT", sorted)).thenReturn(Page.empty());

        service.listWorkOrders("DRAFT", "URGENT", sorted);

        verify(workOrderRepo).findByOrgIdAndStatusAndPriorityAndIsDeletedFalse(
                orgId, "DRAFT", "URGENT", sorted);
    }

    // ── Clone ─────────────────────────────────────────────────────────

    @Test
    void cloneWorkOrder_resetsQuantitiesAndReferences() {
        WorkOrder source = createTestWorkOrder("COMPLETED");
        source.setQuantityProduced(BigDecimal.TEN);
        source.setSalesOrderId(UUID.randomUUID());
        source.setJournalEntryId(UUID.randomUUID());
        source.setWipJournalEntryId(UUID.randomUUID());
        source.setBomVersion(2);
        source.setRoutingId(UUID.randomUUID());
        source.setBackflushMode(true);
        source.setPriority("HIGH");
        source.setApprovalStatus("APPROVED");
        source.setActualStartDate(LocalDate.now().minusDays(5));
        source.setActualEndDate(LocalDate.now());
        source.getLines().get(0).setIssuedQty(BigDecimal.valueOf(33));
        source.getLines().get(0).setStatus("COMPLETED");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(source.getId(), orgId))
                .thenReturn(Optional.of(source));
        when(workOrderRepo.findMaxWorkOrderNumber(orgId)).thenReturn(5);
        when(workOrderRepo.save(any())).thenAnswer(inv -> {
            WorkOrder wo = inv.getArgument(0);
            if (wo.getId() == null) wo.setId(UUID.randomUUID());
            return wo;
        });

        WorkOrder clone = service.cloneWorkOrder(source.getId());

        assertEquals("WO-00006", clone.getWorkOrderNumber());
        assertEquals("DRAFT", clone.getStatus());
        assertEquals("NONE", clone.getApprovalStatus());
        assertEquals(0, BigDecimal.ZERO.compareTo(clone.getQuantityProduced()));
        assertNull(clone.getSalesOrderId());
        assertNull(clone.getJournalEntryId());
        assertNull(clone.getWipJournalEntryId());
        assertNull(clone.getActualStartDate());
        assertNull(clone.getActualEndDate());

        // copied configuration
        assertEquals(source.getFinishedGoodId(), clone.getFinishedGoodId());
        assertEquals(source.getWarehouseId(), clone.getWarehouseId());
        assertEquals(0, source.getQuantityToProduce().compareTo(clone.getQuantityToProduce()));
        assertEquals(Integer.valueOf(2), clone.getBomVersion());
        assertEquals(source.getRoutingId(), clone.getRoutingId());
        assertTrue(clone.isBackflushMode());
        assertEquals("HIGH", clone.getPriority());

        // lines reset
        assertEquals(1, clone.getLines().size());
        WorkOrderLine line = clone.getLines().get(0);
        assertEquals(rmItemId, line.getItemId());
        assertEquals(0, BigDecimal.ZERO.compareTo(line.getIssuedQty()));
        assertEquals("PENDING", line.getStatus());
        assertEquals(0, BigDecimal.valueOf(30).compareTo(line.getRequiredQty()));
        // RM cost rebuilt from planned quantities: 30 × 50 = 1500
        assertEquals(0, BigDecimal.valueOf(1500).compareTo(clone.getRawMaterialCost()));
    }

    // ── Approval workflow ─────────────────────────────────────────────

    @Test
    void createWorkOrder_activeWorkflowMatches_goesPendingApproval() {
        stubHappyCreate();
        WorkflowDefinition workflow = WorkflowDefinition.builder()
                .code("WORK_ORDER_PRODUCTION_APPROVAL")
                .name("Work Order Production Approval")
                .documentType("WORK_ORDER")
                .triggerCondition("{\"field\":\"workOrder.totalCost\",\"operator\":\"GTE\",\"value\":0}")
                .active(true)
                .build();
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("WORK_ORDER"), anyMap()))
                .thenReturn(Optional.of(workflow));

        WorkOrder result = service.createWorkOrder(
                fgItemId, warehouseId, BigDecimal.TEN,
                null, null, null, null, "Needs approval");

        assertEquals("PENDING_APPROVAL", result.getStatus());
        assertEquals("PENDING", result.getApprovalStatus());
        verify(approvalWorkflowService).requestApproval(
                eq(orgId), eq(workflow), eq("WORK_ORDER"), eq(result.getId()),
                any(), anyMap());
    }

    @Test
    void createWorkOrder_noActiveWorkflow_staysDraft() {
        stubHappyCreate();
        when(approvalWorkflowService.findMatchingWorkflow(eq(orgId), eq("WORK_ORDER"), anyMap()))
                .thenReturn(Optional.empty());

        WorkOrder result = service.createWorkOrder(
                fgItemId, warehouseId, BigDecimal.TEN,
                null, null, null, null, "No approval needed");

        assertEquals("DRAFT", result.getStatus());
        assertEquals("NONE", result.getApprovalStatus());
        verify(approvalWorkflowService, never()).requestApproval(any(), any(), any(), any(), any(), anyMap());
    }

    // ── Yield ─────────────────────────────────────────────────────────

    @Test
    void receiveFinishedGoods_completion_populatesYieldOnCostSummary() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN);

        ArgumentCaptor<ProductionCostSummary> captor = ArgumentCaptor.forClass(ProductionCostSummary.class);
        verify(costSummaryRepo).save(captor.capture());
        // 10 produced / 10 planned = 100.00 % yield
        assertEquals(0, new BigDecimal("100.00").compareTo(captor.getValue().getYieldPercentage()));
        assertEquals(0, BigDecimal.TEN.compareTo(captor.getValue().getProducedQty()));
        assertEquals(0, BigDecimal.TEN.compareTo(captor.getValue().getPlannedQty()));
    }

    // ── Production summary report ─────────────────────────────────────

    @Test
    void getProductionSummary_aggregatesStatusYieldOnTimeAndScrap() {
        LocalDate from = LocalDate.of(2026, 6, 1);
        LocalDate to = LocalDate.of(2026, 6, 30);

        WorkOrder completedOnTime = createTestWorkOrder("COMPLETED");
        completedOnTime.setQuantityProduced(BigDecimal.TEN);
        completedOnTime.setPlannedEndDate(LocalDate.of(2026, 6, 10));
        completedOnTime.setActualEndDate(LocalDate.of(2026, 6, 9));

        WorkOrder completedLate = createTestWorkOrder("COMPLETED");
        completedLate.setQuantityToProduce(BigDecimal.valueOf(20));
        completedLate.setQuantityProduced(BigDecimal.valueOf(20));
        completedLate.setPlannedEndDate(LocalDate.of(2026, 6, 5));
        completedLate.setActualEndDate(LocalDate.of(2026, 6, 8));

        WorkOrder inProgress = createTestWorkOrder("IN_PROGRESS");
        inProgress.setQuantityToProduce(BigDecimal.valueOf(5));
        inProgress.setQuantityProduced(BigDecimal.valueOf(2));

        WorkOrder draft = createTestWorkOrder("DRAFT");
        draft.setQuantityToProduce(BigDecimal.valueOf(8));

        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                eq(orgId), any(Instant.class), any(Instant.class)))
                .thenReturn(List.of(completedOnTime, completedLate, inProgress, draft));

        UUID damageReasonId = UUID.randomUUID();
        ScrapReasonCode damage = ScrapReasonCode.builder()
                .code("DAMAGE").description("Damaged in process").build();
        damage.setId(damageReasonId);
        damage.setOrgId(orgId);
        when(scrapReasonCodeRepo.findByIdAndOrgIdAndIsDeletedFalse(damageReasonId, orgId))
                .thenReturn(Optional.of(damage));

        ProductionScrap scrap1 = ProductionScrap.builder()
                .workOrderId(completedOnTime.getId()).itemId(rmItemId)
                .scrapQty(BigDecimal.valueOf(3)).scrapCost(BigDecimal.valueOf(150))
                .reasonCodeId(damageReasonId).build();
        ProductionScrap scrap2 = ProductionScrap.builder()
                .workOrderId(completedLate.getId()).itemId(rmItemId)
                .scrapQty(BigDecimal.valueOf(2)).scrapCost(BigDecimal.valueOf(100))
                .reasonCodeId(damageReasonId).build();
        ProductionScrap scrap3 = ProductionScrap.builder()
                .workOrderId(inProgress.getId()).itemId(rmItemId)
                .scrapQty(BigDecimal.ONE).scrapCost(BigDecimal.valueOf(50))
                .reasonCodeId(null).build();
        when(productionScrapRepo.findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                eq(orgId), any(Instant.class), any(Instant.class)))
                .thenReturn(List.of(scrap1, scrap2, scrap3));

        Map<String, Object> result = service.getProductionSummary(from, to);

        assertEquals(4, result.get("totalWorkOrders"));
        @SuppressWarnings("unchecked")
        Map<String, Long> statusCounts = (Map<String, Long>) result.get("statusCounts");
        assertEquals(2L, statusCounts.get("COMPLETED"));
        assertEquals(1L, statusCounts.get("IN_PROGRESS"));
        assertEquals(1L, statusCounts.get("DRAFT"));

        assertEquals(2, result.get("completedCount"));
        assertEquals(0, new BigDecimal("50.00").compareTo((BigDecimal) result.get("completionRate")));
        // 1 of 2 measured completed WOs finished on or before plan
        assertEquals(0, new BigDecimal("50.00").compareTo((BigDecimal) result.get("onTimePercent")));
        assertEquals(2, result.get("onTimeMeasuredCount"));

        // planned: 10 + 20 + 5 + 8 = 43, produced: 10 + 20 + 2 + 0 = 32
        assertEquals(0, BigDecimal.valueOf(43).compareTo((BigDecimal) result.get("totalPlannedQty")));
        assertEquals(0, BigDecimal.valueOf(32).compareTo((BigDecimal) result.get("totalProducedQty")));
        // both completed orders are at 100% yield
        assertEquals(0, new BigDecimal("100.00").compareTo((BigDecimal) result.get("averageYieldPercent")));

        assertEquals(0, BigDecimal.valueOf(6).compareTo((BigDecimal) result.get("totalScrapQty")));
        assertEquals(0, BigDecimal.valueOf(300).compareTo((BigDecimal) result.get("totalScrapCost")));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> scrapByReason = (List<Map<String, Object>>) result.get("scrapByReason");
        assertEquals(2, scrapByReason.size());
        Map<String, Object> damageRow = scrapByReason.stream()
                .filter(r -> "DAMAGE".equals(r.get("reasonCode"))).findFirst().orElseThrow();
        assertEquals(0, BigDecimal.valueOf(5).compareTo((BigDecimal) damageRow.get("totalQty")));
        assertEquals(0, BigDecimal.valueOf(250).compareTo((BigDecimal) damageRow.get("totalCost")));
        Map<String, Object> unspecifiedRow = scrapByReason.stream()
                .filter(r -> "UNSPECIFIED".equals(r.get("reasonCode"))).findFirst().orElseThrow();
        assertEquals(0, BigDecimal.ONE.compareTo((BigDecimal) unspecifiedRow.get("totalQty")));
    }

    @Test
    void getProductionSummary_invalidRange_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.getProductionSummary(LocalDate.of(2026, 6, 30), LocalDate.of(2026, 6, 1)));
        assertEquals("MFG_INVALID_DATE_RANGE", ex.getErrorCode());
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private void stubHappyCreate() {
        Item fg = buildCompositeItem();
        Item rm = buildRawMaterial();
        BomComponent bom = buildBomComponent();

        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(bom));
        when(bomComponentRepo.findMaxVersion(orgId, fgItemId)).thenReturn(1);
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(workOrderRepo.findMaxWorkOrderNumber(orgId)).thenReturn(0);
        when(workOrderRepo.save(any())).thenAnswer(inv -> {
            WorkOrder wo = inv.getArgument(0);
            if (wo.getId() == null) wo.setId(UUID.randomUUID());
            return wo;
        });
    }

    private Item buildCompositeItem() {
        Item fg = Item.builder()
                .sku("FG-001").name("Finished Good")
                .itemType(ItemType.COMPOSITE)
                .purchasePrice(BigDecimal.ZERO)
                .salePrice(BigDecimal.valueOf(500))
                .build();
        fg.setId(fgItemId);
        fg.setOrgId(orgId);
        return fg;
    }

    private Item buildRawMaterial() {
        Item rm = Item.builder()
                .sku("RM-001").name("Raw Material")
                .itemType(ItemType.GOODS)
                .purchasePrice(BigDecimal.valueOf(50))
                .salePrice(BigDecimal.ZERO)
                .build();
        rm.setId(rmItemId);
        rm.setOrgId(orgId);
        return rm;
    }

    private BomComponent buildBomComponent() {
        BomComponent comp = BomComponent.builder()
                .parentItemId(fgItemId)
                .childItemId(rmItemId)
                .quantity(BigDecimal.valueOf(3))
                .build();
        comp.setOrgId(orgId);
        return comp;
    }

    private WorkOrder createTestWorkOrder(String status) {
        WorkOrderLine line = WorkOrderLine.builder()
                .itemId(rmItemId)
                .requiredQty(BigDecimal.valueOf(30))
                .issuedQty(BigDecimal.ZERO)
                .unitCost(BigDecimal.valueOf(50))
                .lineCost(BigDecimal.valueOf(1500))
                .status("PENDING")
                .build();

        WorkOrder wo = WorkOrder.builder()
                .workOrderNumber("WO-00001")
                .finishedGoodId(fgItemId)
                .warehouseId(warehouseId)
                .quantityToProduce(BigDecimal.TEN)
                .quantityProduced(BigDecimal.ZERO)
                .status(status)
                .rawMaterialCost(BigDecimal.valueOf(1500))
                .directLaborCost(BigDecimal.ZERO)
                .overheadCost(BigDecimal.ZERO)
                .totalCost(BigDecimal.valueOf(1500))
                .unitCost(BigDecimal.valueOf(150))
                .lines(new java.util.ArrayList<>(List.of(line)))
                .build();
        wo.setId(UUID.randomUUID());
        wo.setOrgId(orgId);
        line.setWorkOrder(wo);
        return wo;
    }
}
