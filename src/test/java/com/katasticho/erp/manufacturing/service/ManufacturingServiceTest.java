package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.ManufacturingWipPostingRule;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.BomAlternate;
import com.katasticho.erp.inventory.entity.BomCoProduct;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
import com.katasticho.erp.inventory.repository.BomAlternateRepository;
import com.katasticho.erp.inventory.repository.BomCoProductRepository;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.ProductionCostSummaryRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderLineRepository;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ManufacturingServiceTest {

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
    @Mock private com.katasticho.erp.common.workflow.ApprovalWorkflowService approvalWorkflowService;
    @Mock private com.katasticho.erp.manufacturing.repository.ProductionScrapRepository productionScrapRepo;
    @Mock private com.katasticho.erp.manufacturing.repository.ScrapReasonCodeRepository scrapReasonCodeRepo;
    @Mock private com.katasticho.erp.inventory.repository.StockBatchRepository stockBatchRepo;
    @Mock private com.katasticho.erp.inventory.service.BatchTraceService batchTraceService;

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
                productionScrapRepo, scrapReasonCodeRepo, stockBatchRepo, batchTraceService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
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

    @Test
    void createWorkOrder_compositeItem_succeeds() {
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

        WorkOrder result = service.createWorkOrder(
                fgItemId, warehouseId, BigDecimal.TEN,
                null, null, null, null, "Test WO");

        assertEquals("DRAFT", result.getStatus());
        assertEquals("WO-00001", result.getWorkOrderNumber());
        assertEquals(1, result.getLines().size());
        assertEquals(0, BigDecimal.valueOf(30).compareTo(result.getLines().get(0).getRequiredQty()));
        assertEquals(0, BigDecimal.valueOf(1500).compareTo(result.getRawMaterialCost()));
    }

    @Test
    void createWorkOrder_nonComposite_throws() {
        Item goods = Item.builder().sku("ITEM-01").itemType(ItemType.GOODS).build();
        goods.setId(fgItemId);
        goods.setOrgId(orgId);

        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(goods));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createWorkOrder(fgItemId, warehouseId, BigDecimal.TEN,
                        null, null, null, null, null));
        assertEquals("MFG_NOT_COMPOSITE", ex.getErrorCode());
    }

    @Test
    void createWorkOrder_noBom_throws() {
        Item fg = buildCompositeItem();

        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createWorkOrder(fgItemId, warehouseId, BigDecimal.TEN,
                        null, null, null, null, null));
        assertEquals("MFG_NO_BOM", ex.getErrorCode());
    }

    @Test
    void createWorkOrder_zeroQuantity_throws() {
        Item fg = buildCompositeItem();
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createWorkOrder(fgItemId, warehouseId, BigDecimal.ZERO,
                        null, null, null, null, null));
        assertEquals("MFG_INVALID_QUANTITY", ex.getErrorCode());
    }

    @Test
    void issueToProduction_draftOrder_deductsStockAndPostsWipJournal() {
        WorkOrder wo = createTestWorkOrder("DRAFT");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JournalEntry mockEntry = new JournalEntry();
        mockEntry.setId(UUID.randomUUID());
        mockEntry.setEntryNumber("JE-2026-000001");
        when(wipPostingRule.generate(any())).thenReturn(
                new com.katasticho.erp.accounting.dto.JournalPostRequest(
                        java.time.LocalDate.now(), "WIP", "MANUFACTURING", wo.getId(),
                        List.of(new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1210", BigDecimal.valueOf(1500), BigDecimal.ZERO, "WIP", null, null),
                                new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1200", BigDecimal.ZERO, BigDecimal.valueOf(1500), "RM", null, null)),
                        true));
        when(journalService.postJournal(any())).thenReturn(mockEntry);

        WorkOrder result = service.issueToProduction(wo.getId());

        assertEquals("IN_PROGRESS", result.getStatus());
        assertNotNull(result.getActualStartDate());
        assertEquals("ISSUED", result.getLines().get(0).getStatus());
        assertNotNull(result.getWipJournalEntryId());
        verify(inventoryService, times(1)).recordMovement(any());
        verify(journalService, times(1)).postJournal(any());
    }

    @Test
    void issueToProduction_notDraft_throws() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.issueToProduction(wo.getId()));
        assertEquals("MFG_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void receiveFinishedGoods_fullQuantity_completesOrderAndBuildsCostSummary() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JournalEntry mockEntry = new JournalEntry();
        mockEntry.setId(UUID.randomUUID());
        when(wipPostingRule.generate(any())).thenReturn(
                new com.katasticho.erp.accounting.dto.JournalPostRequest(
                        java.time.LocalDate.now(), "Completion", "MANUFACTURING", wo.getId(),
                        List.of(new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1200", BigDecimal.valueOf(1500), BigDecimal.ZERO, "FG", null, null),
                                new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1210", BigDecimal.ZERO, BigDecimal.valueOf(1500), "WIP", null, null)),
                        true));
        when(journalService.postJournal(any())).thenReturn(mockEntry);
        when(costSummaryRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN);

        assertEquals("COMPLETED", result.getStatus());
        assertEquals(0, BigDecimal.TEN.compareTo(result.getQuantityProduced()));
        assertNotNull(result.getActualEndDate());
        assertNotNull(result.getJournalEntryId());
        verify(inventoryService).recordMovement(any());
        verify(costSummaryRepo).save(any());
    }

    @Test
    void receiveFinishedGoods_withBatchNumber_upsertsBatch_andStampsMovement() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        com.katasticho.erp.inventory.entity.Item fg = com.katasticho.erp.inventory.entity.Item.builder()
                .name("Tab Atorva 10mg").trackBatches(true).build();
        fg.setId(fgItemId);
        fg.setOrgId(orgId);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(stockBatchRepo.findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse(orgId, fgItemId, "ATV-2026-07"))
                .thenReturn(Optional.empty());
        when(stockBatchRepo.save(any())).thenAnswer(inv -> {
            com.katasticho.erp.inventory.entity.StockBatch b = inv.getArgument(0);
            b.setId(UUID.randomUUID());
            return b;
        });
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        // Skip journal/cost-summary side effects (covered by sibling tests).
        when(wipPostingRule.generate(any())).thenReturn(
                new com.katasticho.erp.accounting.dto.JournalPostRequest(
                        java.time.LocalDate.now(), "x", "MANUFACTURING", wo.getId(),
                        List.of(new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1200", BigDecimal.ONE, BigDecimal.ZERO, "x", null, null),
                                new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                        "1210", BigDecimal.ZERO, BigDecimal.ONE, "x", null, null)),
                        true));
        JournalEntry je = new JournalEntry();
        je.setId(UUID.randomUUID());
        when(journalService.postJournal(any())).thenReturn(je);
        when(costSummaryRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        java.time.LocalDate expiry = java.time.LocalDate.now().plusYears(2);
        service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN, "ATV-2026-07", expiry);

        org.mockito.ArgumentCaptor<com.katasticho.erp.inventory.entity.StockBatch> batchCap =
                org.mockito.ArgumentCaptor.forClass(com.katasticho.erp.inventory.entity.StockBatch.class);
        verify(stockBatchRepo).save(batchCap.capture());
        assertEquals("ATV-2026-07", batchCap.getValue().getBatchNumber());
        assertEquals(expiry, batchCap.getValue().getExpiryDate());
        assertEquals(orgId, batchCap.getValue().getOrgId());

        org.mockito.ArgumentCaptor<com.katasticho.erp.inventory.dto.StockMovementRequest> movCap =
                org.mockito.ArgumentCaptor.forClass(com.katasticho.erp.inventory.dto.StockMovementRequest.class);
        verify(inventoryService).recordMovement(movCap.capture());
        assertNotNull(movCap.getValue().batchId(), "FG movement must carry the resolved batch id");
    }

    @Test
    void receiveFinishedGoods_batchTrackedItem_withoutBatchNumber_throws() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        com.katasticho.erp.inventory.entity.Item fg = com.katasticho.erp.inventory.entity.Item.builder()
                .name("Tab Atorva 10mg").trackBatches(true).build();
        fg.setId(fgItemId);
        fg.setOrgId(orgId);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));

        com.katasticho.erp.common.exception.BusinessException ex =
                assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                        () -> service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN, null, null));
        assertEquals("MFG_BATCH_REQUIRED", ex.getErrorCode());
        verify(stockBatchRepo, org.mockito.Mockito.never()).save(any());
        verify(inventoryService, org.mockito.Mockito.never()).recordMovement(any());
    }

    @Test
    void receiveFinishedGoods_nonBatchItem_withBatchNumber_throws() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        com.katasticho.erp.inventory.entity.Item fg = com.katasticho.erp.inventory.entity.Item.builder()
                .name("Plain Tea Powder").trackBatches(false).build();
        fg.setId(fgItemId);
        fg.setOrgId(orgId);
        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));

        com.katasticho.erp.common.exception.BusinessException ex =
                assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                        () -> service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN, "BX-1", null));
        assertEquals("MFG_ITEM_NOT_BATCH_TRACKED", ex.getErrorCode());
    }

    @Test
    void productionTrends_emitsBucketPerDay_inWindow_evenWithZeroActivity() {
        java.time.LocalDate from = java.time.LocalDate.now().minusDays(2);
        java.time.LocalDate to = java.time.LocalDate.now();
        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of());
        when(productionScrapRepo.findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of());

        List<java.util.Map<String, Object>> trends = service.productionTrends(from, to);

        assertEquals(3, trends.size(), "3 days inclusive");
        assertEquals(from, trends.get(0).get("date"));
        assertEquals(to, trends.get(2).get("date"));
        assertEquals(0L, trends.get(0).get("woStarted"));
        assertEquals(0L, trends.get(0).get("woCompleted"));
    }

    @Test
    void productionTrends_attributesCompletedWoToActualEndDate() {
        java.time.LocalDate from = java.time.LocalDate.now().minusDays(3);
        java.time.LocalDate to = java.time.LocalDate.now();
        WorkOrder wo = createTestWorkOrder("COMPLETED");
        wo.setActualStartDate(from.plusDays(1));
        wo.setActualEndDate(from.plusDays(2));
        wo.setQuantityProduced(BigDecimal.valueOf(50));
        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of(wo));
        when(productionScrapRepo.findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of());

        List<java.util.Map<String, Object>> trends = service.productionTrends(from, to);

        java.util.Map<String, Object> startedDay = trends.get(1); // from + 1
        java.util.Map<String, Object> endedDay = trends.get(2);   // from + 2
        assertEquals(1L, startedDay.get("woStarted"));
        assertEquals(0L, startedDay.get("woCompleted"));
        assertEquals(0L, endedDay.get("woStarted"));
        assertEquals(1L, endedDay.get("woCompleted"));
        assertEquals(0, ((BigDecimal) endedDay.get("quantityProduced")).compareTo(BigDecimal.valueOf(50)));
    }

    @Test
    void workOrderProfitability_completedWoWithSoLink_computesRevenueCostMargin() {
        WorkOrder wo = createTestWorkOrder("COMPLETED");
        wo.setActualEndDate(java.time.LocalDate.now());
        wo.setQuantityProduced(BigDecimal.valueOf(10));
        UUID soId = UUID.randomUUID();
        wo.setSalesOrderId(soId);

        com.katasticho.erp.sales.entity.SalesOrderLine line =
                com.katasticho.erp.sales.entity.SalesOrderLine.builder()
                        .itemId(fgItemId)
                        .rate(new BigDecimal("250.00"))
                        .build();
        com.katasticho.erp.sales.entity.SalesOrder so =
                com.katasticho.erp.sales.entity.SalesOrder.builder()
                        .lines(new java.util.ArrayList<>(List.of(line)))
                        .build();

        com.katasticho.erp.manufacturing.entity.ProductionCostSummary cs =
                com.katasticho.erp.manufacturing.entity.ProductionCostSummary.builder()
                        .workOrderId(wo.getId())
                        .actualTotal(new BigDecimal("1800.00"))
                        .build();

        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of(wo));
        when(costSummaryRepo.findByWorkOrderIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(cs));
        when(salesOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        java.time.LocalDate from = java.time.LocalDate.now().minusDays(7);
        java.time.LocalDate to = java.time.LocalDate.now();
        List<java.util.Map<String, Object>> rows = service.workOrderProfitability(from, to);

        assertEquals(1, rows.size());
        // 10 produced × ₹250 = ₹2500 revenue − ₹1800 cost = ₹700 profit @ 28% margin.
        assertEquals(0, ((BigDecimal) rows.get(0).get("revenue")).compareTo(new BigDecimal("2500.00")));
        assertEquals(0, ((BigDecimal) rows.get(0).get("cost")).compareTo(new BigDecimal("1800.00")));
        assertEquals(0, ((BigDecimal) rows.get(0).get("profit")).compareTo(new BigDecimal("700.00")));
        assertEquals(0, ((BigDecimal) rows.get(0).get("marginPercent")).compareTo(new BigDecimal("28.00")));
        assertEquals("SO_LINE", rows.get(0).get("revenueSource"));
    }

    @Test
    void workOrderProfitability_completedWoWithoutSoLink_revenueZero_sourceNONE() {
        WorkOrder wo = createTestWorkOrder("COMPLETED");
        wo.setQuantityProduced(BigDecimal.valueOf(5));
        wo.setSalesOrderId(null);
        com.katasticho.erp.manufacturing.entity.ProductionCostSummary cs =
                com.katasticho.erp.manufacturing.entity.ProductionCostSummary.builder()
                        .workOrderId(wo.getId())
                        .actualTotal(new BigDecimal("500.00"))
                        .build();
        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of(wo));
        when(costSummaryRepo.findByWorkOrderIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(cs));

        List<java.util.Map<String, Object>> rows = service.workOrderProfitability(
                java.time.LocalDate.now().minusDays(7), java.time.LocalDate.now());
        assertEquals(1, rows.size());
        assertEquals("NONE", rows.get(0).get("revenueSource"));
        assertEquals(0, ((BigDecimal) rows.get(0).get("revenue")).compareTo(BigDecimal.ZERO));
        assertEquals(0, ((BigDecimal) rows.get(0).get("profit")).compareTo(new BigDecimal("-500.00")));
    }

    @Test
    void scrapRateDashboard_aggregatesByItemAndReason_withRateOverProducedPlusScrap() {
        WorkOrder wo = createTestWorkOrder("COMPLETED");
        wo.setQuantityProduced(BigDecimal.valueOf(90));
        UUID reasonId = UUID.randomUUID();
        com.katasticho.erp.manufacturing.entity.ScrapReasonCode reason =
                com.katasticho.erp.manufacturing.entity.ScrapReasonCode.builder()
                        .code("CONT").description("Contamination").build();
        com.katasticho.erp.manufacturing.entity.ProductionScrap scrap =
                com.katasticho.erp.manufacturing.entity.ProductionScrap.builder()
                        .workOrderId(wo.getId())
                        .itemId(fgItemId)
                        .reasonCodeId(reasonId)
                        .scrapQty(BigDecimal.TEN)
                        .scrapCost(new BigDecimal("200.00"))
                        .build();
        com.katasticho.erp.inventory.entity.Item fg = com.katasticho.erp.inventory.entity.Item.builder()
                .name("Tab Atorva 10mg").build();
        fg.setId(fgItemId);

        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of(wo));
        when(productionScrapRepo.findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of(scrap));
        when(scrapReasonCodeRepo.findByIdAndOrgIdAndIsDeletedFalse(reasonId, orgId))
                .thenReturn(Optional.of(reason));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));

        java.util.Map<String, Object> dash = service.scrapRateDashboard(
                java.time.LocalDate.now().minusDays(7), java.time.LocalDate.now());

        @SuppressWarnings("unchecked")
        List<java.util.Map<String, Object>> byItem =
                (List<java.util.Map<String, Object>>) dash.get("byItem");
        assertEquals(1, byItem.size());
        assertEquals(0, ((BigDecimal) byItem.get(0).get("scrapQty")).compareTo(BigDecimal.TEN));
        assertEquals(0, ((BigDecimal) byItem.get(0).get("producedQty")).compareTo(BigDecimal.valueOf(90)));
        // 10 / (90 + 10) = 10%
        assertEquals(0, ((BigDecimal) byItem.get(0).get("scrapRatePercent"))
                .compareTo(new BigDecimal("10.00")));

        @SuppressWarnings("unchecked")
        List<java.util.Map<String, Object>> byReason =
                (List<java.util.Map<String, Object>>) dash.get("byReason");
        assertEquals(1, byReason.size());
        assertEquals("CONT", byReason.get(0).get("reasonCode"));
    }

    @Test
    void scrapRateDashboard_emptyWindow_returnsZeros() {
        when(workOrderRepo.findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of());
        when(productionScrapRepo.findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
                org.mockito.ArgumentMatchers.eq(orgId),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class),
                org.mockito.ArgumentMatchers.any(java.time.Instant.class)))
                .thenReturn(List.of());

        java.util.Map<String, Object> dash = service.scrapRateDashboard(
                java.time.LocalDate.now().minusDays(1), java.time.LocalDate.now());
        assertEquals(0, ((BigDecimal) dash.get("totalScrapQty")).compareTo(BigDecimal.ZERO));
        assertEquals(0, ((BigDecimal) dash.get("totalScrapCost")).compareTo(BigDecimal.ZERO));
    }

    @Test
    void diffBomVersions_groupsAddedRemovedChanged_andResolvesNames() {
        UUID parent = UUID.randomUUID();
        UUID rmA = UUID.randomUUID();
        UUID rmB = UUID.randomUUID();
        UUID rmC = UUID.randomUUID();

        com.katasticho.erp.inventory.entity.BomComponent v1A =
                com.katasticho.erp.inventory.entity.BomComponent.builder()
                        .parentItemId(parent).childItemId(rmA)
                        .quantity(new BigDecimal("5"))
                        .scrapPercent(new BigDecimal("2"))
                        .version(1).build();
        com.katasticho.erp.inventory.entity.BomComponent v1B =
                com.katasticho.erp.inventory.entity.BomComponent.builder()
                        .parentItemId(parent).childItemId(rmB)
                        .quantity(new BigDecimal("3"))
                        .version(1).build();
        com.katasticho.erp.inventory.entity.BomComponent v2A =
                com.katasticho.erp.inventory.entity.BomComponent.builder()
                        .parentItemId(parent).childItemId(rmA)
                        .quantity(new BigDecimal("7"))      // qty changed 5 → 7
                        .scrapPercent(new BigDecimal("2"))
                        .version(2).build();
        com.katasticho.erp.inventory.entity.BomComponent v2C =
                com.katasticho.erp.inventory.entity.BomComponent.builder()
                        .parentItemId(parent).childItemId(rmC)
                        .quantity(new BigDecimal("1"))
                        .version(2).build();

        when(bomComponentRepo.findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                orgId, parent, 1)).thenReturn(List.of(v1A, v1B));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                orgId, parent, 2)).thenReturn(List.of(v2A, v2C));

        com.katasticho.erp.inventory.entity.Item nameA =
                com.katasticho.erp.inventory.entity.Item.builder().name("Atorva API").build();
        com.katasticho.erp.inventory.entity.Item nameB =
                com.katasticho.erp.inventory.entity.Item.builder().name("Lactose").build();
        com.katasticho.erp.inventory.entity.Item nameC =
                com.katasticho.erp.inventory.entity.Item.builder().name("Maize Starch").build();
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmA, orgId)).thenReturn(Optional.of(nameA));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmB, orgId)).thenReturn(Optional.of(nameB));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmC, orgId)).thenReturn(Optional.of(nameC));

        java.util.Map<String, Object> diff = service.diffBomVersions(parent, 1, 2);

        assertEquals(1, diff.get("addedCount"));
        assertEquals(1, diff.get("removedCount"));
        assertEquals(1, diff.get("changedCount"));

        @SuppressWarnings("unchecked")
        List<java.util.Map<String, Object>> added =
                (List<java.util.Map<String, Object>>) diff.get("added");
        assertEquals("Maize Starch", added.get(0).get("childItemName"));

        @SuppressWarnings("unchecked")
        List<java.util.Map<String, Object>> removed =
                (List<java.util.Map<String, Object>>) diff.get("removed");
        assertEquals("Lactose", removed.get(0).get("childItemName"));

        @SuppressWarnings("unchecked")
        List<java.util.Map<String, Object>> changed =
                (List<java.util.Map<String, Object>>) diff.get("changed");
        assertEquals("Atorva API", changed.get(0).get("childItemName"));
        assertEquals(0, ((BigDecimal) changed.get(0).get("fromQty")).compareTo(new BigDecimal("5")));
        assertEquals(0, ((BigDecimal) changed.get(0).get("toQty")).compareTo(new BigDecimal("7")));
        assertEquals(0, ((BigDecimal) changed.get(0).get("qtyDelta")).compareTo(new BigDecimal("2")));
    }

    @Test
    void diffBomVersions_identicalVersions_returnsAllUnchanged() {
        UUID parent = UUID.randomUUID();
        UUID rmA = UUID.randomUUID();
        com.katasticho.erp.inventory.entity.BomComponent comp =
                com.katasticho.erp.inventory.entity.BomComponent.builder()
                        .parentItemId(parent).childItemId(rmA)
                        .quantity(new BigDecimal("5"))
                        .scrapPercent(new BigDecimal("2"))
                        .version(1).build();
        com.katasticho.erp.inventory.entity.BomComponent comp2 =
                com.katasticho.erp.inventory.entity.BomComponent.builder()
                        .parentItemId(parent).childItemId(rmA)
                        .quantity(new BigDecimal("5"))
                        .scrapPercent(new BigDecimal("2"))
                        .version(2).build();
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                orgId, parent, 1)).thenReturn(List.of(comp));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                orgId, parent, 2)).thenReturn(List.of(comp2));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmA, orgId)).thenReturn(Optional.empty());

        java.util.Map<String, Object> diff = service.diffBomVersions(parent, 1, 2);

        assertEquals(0, diff.get("addedCount"));
        assertEquals(0, diff.get("removedCount"));
        assertEquals(0, diff.get("changedCount"));
        assertEquals(1, diff.get("unchangedCount"));
    }

    @Test
    void diffBomVersions_sameVersionNumber_throws() {
        com.katasticho.erp.common.exception.BusinessException ex =
                assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                        () -> service.diffBomVersions(UUID.randomUUID(), 1, 1));
        assertEquals("BOM_DIFF_SAME_VERSION", ex.getErrorCode());
    }

    @Test
    void diffBomVersions_bothVersionsEmpty_throwsNotFound() {
        UUID parent = UUID.randomUUID();
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                orgId, parent, 1)).thenReturn(List.of());
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndVersionAndIsDeletedFalseOrderByCreatedAtAsc(
                orgId, parent, 2)).thenReturn(List.of());

        com.katasticho.erp.common.exception.BusinessException ex =
                assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                        () -> service.diffBomVersions(parent, 1, 2));
        assertEquals("BOM_DIFF_VERSIONS_EMPTY", ex.getErrorCode());
    }

    @Test
    void receiveFinishedGoods_partialQuantity_staysInProgress() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.receiveFinishedGoods(wo.getId(), BigDecimal.valueOf(5));

        assertEquals("IN_PROGRESS", result.getStatus());
        assertEquals(0, BigDecimal.valueOf(5).compareTo(result.getQuantityProduced()));
    }

    @Test
    void receiveFinishedGoods_exceedsPlanned_throws() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.receiveFinishedGoods(wo.getId(), BigDecimal.valueOf(20)));
        assertEquals("MFG_EXCEEDS_PLANNED", ex.getErrorCode());
    }

    @Test
    void cancelWorkOrder_inProgress_reversesStockAndJournal() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        wo.getLines().get(0).setIssuedQty(BigDecimal.valueOf(30));
        UUID wipJournalId = UUID.randomUUID();
        wo.setWipJournalEntryId(wipJournalId);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.cancelWorkOrder(wo.getId());

        assertEquals("CANCELLED", result.getStatus());
        assertEquals("CANCELLED", result.getLines().get(0).getStatus());
        verify(inventoryService, times(1)).recordMovement(any());
        verify(journalService, times(1)).reverseEntry(wipJournalId);
    }

    @Test
    void cancelWorkOrder_completed_throws() {
        WorkOrder wo = createTestWorkOrder("COMPLETED");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancelWorkOrder(wo.getId()));
        assertEquals("MFG_ALREADY_COMPLETED", ex.getErrorCode());
    }

    @Test
    void updateCosts_recalculatesTotal() {
        WorkOrder wo = createTestWorkOrder("DRAFT");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.updateCosts(wo.getId(),
                BigDecimal.valueOf(2000), BigDecimal.valueOf(500));

        assertEquals(0, BigDecimal.valueOf(2000).compareTo(result.getDirectLaborCost()));
        assertEquals(0, BigDecimal.valueOf(500).compareTo(result.getOverheadCost()));
        assertTrue(result.getTotalCost().compareTo(BigDecimal.valueOf(2500)) >= 0);
    }

    @Test
    void createWorkOrdersFromSalesOrder_compositeItems_createsWOs() {
        UUID soId = UUID.randomUUID();
        Item fg = buildCompositeItem();
        Item rm = buildRawMaterial();
        BomComponent bom = buildBomComponent();

        SalesOrder so = SalesOrder.builder()
                .salesorderNumber("SO-00001")
                .contactId(UUID.randomUUID())
                .orderDate(java.time.LocalDate.now())
                .status("CONFIRMED")
                .lines(new java.util.ArrayList<>())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);

        SalesOrderLine soLine = SalesOrderLine.builder()
                .salesOrder(so)
                .lineNumber(1)
                .itemId(fgItemId)
                .quantity(BigDecimal.valueOf(5))
                .rate(BigDecimal.valueOf(500))
                .amount(BigDecimal.valueOf(2500))
                .build();
        soLine.setId(UUID.randomUUID());
        so.getLines().add(soLine);

        Warehouse wh = Warehouse.builder().name("Main").isDefault(true).build();
        wh.setId(warehouseId);
        wh.setOrgId(orgId);

        when(salesOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(warehouseRepo.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(wh));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId))
                .thenReturn(Optional.of(fg));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId))
                .thenReturn(Optional.of(rm));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(bom));
        when(bomComponentRepo.findMaxVersion(orgId, fgItemId)).thenReturn(1);
        when(workOrderRepo.findMaxWorkOrderNumber(orgId)).thenReturn(0);
        when(workOrderRepo.save(any())).thenAnswer(inv -> {
            WorkOrder wo = inv.getArgument(0);
            if (wo.getId() == null) wo.setId(UUID.randomUUID());
            return wo;
        });

        List<WorkOrder> result = service.createWorkOrdersFromSalesOrder(soId, null);

        assertEquals(1, result.size());
        assertEquals(soId, result.get(0).getSalesOrderId());
        assertEquals(0, BigDecimal.valueOf(5).compareTo(result.get(0).getQuantityToProduce()));
    }

    @Test
    void createWorkOrdersFromSalesOrder_draftSO_throws() {
        UUID soId = UUID.randomUUID();
        SalesOrder so = SalesOrder.builder()
                .salesorderNumber("SO-00001")
                .contactId(UUID.randomUUID())
                .orderDate(java.time.LocalDate.now())
                .status("DRAFT")
                .build();
        so.setId(soId);
        so.setOrgId(orgId);

        when(salesOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createWorkOrdersFromSalesOrder(soId, null));
        assertEquals("MFG_SO_NOT_CONFIRMED", ex.getErrorCode());
    }

    @Test
    void createWorkOrdersFromSalesOrder_noCompositeItems_throws() {
        UUID soId = UUID.randomUUID();
        Item goods = Item.builder().sku("ITEM-01").itemType(ItemType.GOODS).build();
        goods.setId(fgItemId);
        goods.setOrgId(orgId);

        SalesOrder so = SalesOrder.builder()
                .salesorderNumber("SO-00001")
                .contactId(UUID.randomUUID())
                .orderDate(java.time.LocalDate.now())
                .status("CONFIRMED")
                .lines(new java.util.ArrayList<>())
                .build();
        so.setId(soId);
        so.setOrgId(orgId);

        SalesOrderLine soLine = SalesOrderLine.builder()
                .salesOrder(so)
                .lineNumber(1)
                .itemId(fgItemId)
                .quantity(BigDecimal.valueOf(5))
                .rate(BigDecimal.valueOf(500))
                .amount(BigDecimal.valueOf(2500))
                .build();
        soLine.setId(UUID.randomUUID());
        so.getLines().add(soLine);

        Warehouse wh = Warehouse.builder().name("Main").isDefault(true).build();
        wh.setId(warehouseId);
        wh.setOrgId(orgId);

        when(salesOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(soId, orgId))
                .thenReturn(Optional.of(so));
        when(warehouseRepo.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId))
                .thenReturn(Optional.of(wh));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId))
                .thenReturn(Optional.of(goods));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createWorkOrdersFromSalesOrder(soId, null));
        assertEquals("MFG_SO_NO_COMPOSITE_ITEMS", ex.getErrorCode());
    }

    // ── Tier 2: Backflush ────────────────────────────────────────────

    @Test
    void issueToProduction_backflushMode_doesNotDeductStock() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        wo.setBackflushMode(true);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.issueToProduction(wo.getId());

        assertEquals("IN_PROGRESS", result.getStatus());
        verify(inventoryService, never()).recordMovement(any());
        assertEquals("PENDING", result.getLines().get(0).getStatus());
    }

    @Test
    void receiveFinishedGoods_backflushMode_deductsProportionalStock() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        wo.setBackflushMode(true);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        JournalEntry mockEntry = new JournalEntry();
        mockEntry.setId(UUID.randomUUID());
        when(wipPostingRule.generate(any())).thenReturn(
                new com.katasticho.erp.accounting.dto.JournalPostRequest(
                        java.time.LocalDate.now(), "Completion", "MANUFACTURING", wo.getId(),
                        List.of(new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1200", BigDecimal.valueOf(1500), BigDecimal.ZERO, "FG", null, null),
                                new com.katasticho.erp.accounting.dto.JournalLineRequest(
                                "1210", BigDecimal.ZERO, BigDecimal.valueOf(1500), "WIP", null, null)),
                        true));
        when(journalService.postJournal(any())).thenReturn(mockEntry);
        when(costSummaryRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN);

        assertEquals("COMPLETED", result.getStatus());
        // backflush issue (1 call) + FG receipt (1 call) = 2 total
        verify(inventoryService, times(2)).recordMovement(any());
    }

    // ── Tier 2: Disassembly ──────────────────────────────────────────

    @Test
    void executeDisassembly_reversesStockCorrectly() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        wo.setDisassembly(true);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.executeDisassembly(wo.getId());

        assertEquals("COMPLETED", result.getStatus());
        // 1 FG consumption + 1 component recovery = 2
        verify(inventoryService, times(2)).recordMovement(any());
    }

    @Test
    void executeDisassembly_notDisassemblyOrder_throws() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        wo.setDisassembly(false);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.executeDisassembly(wo.getId()));
        assertEquals("MFG_NOT_DISASSEMBLY", ex.getErrorCode());
    }

    // ── Tier 2: BOM Versioning ───────────────────────────────────────

    @Test
    void createBomVersion_createsNewVersionFromCurrent() {
        Item fg = buildCompositeItem();
        BomComponent comp = buildBomComponent();
        comp.setId(UUID.randomUUID());

        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(bomComponentRepo.findMaxVersion(orgId, fgItemId)).thenReturn(1);
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(comp));
        when(bomComponentRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        int newVersion = service.createBomVersion(fgItemId, "Updated quantities");

        assertEquals(2, newVersion);
        // 1 save for closing old comp + 1 save for new comp = 2
        verify(bomComponentRepo, times(2)).save(any());
    }

    // ── Tier 2: WIP Valuation Report ─────────────────────────────────

    @Test
    void getWipValuation_sumsInProgressOrders() {
        WorkOrder wo1 = createTestWorkOrder("IN_PROGRESS");
        WorkOrder wo2 = createTestWorkOrder("IN_PROGRESS");
        wo2.setRawMaterialCost(BigDecimal.valueOf(3000));
        wo2.setDirectLaborCost(BigDecimal.valueOf(500));

        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(orgId, List.of("IN_PROGRESS")))
                .thenReturn(List.of(wo1, wo2));

        var result = service.getWipValuation();

        assertNotNull(result.get("totalWipValue"));
        assertEquals(2, result.get("wipOrderCount"));
    }

    // ── BOM Enhancements: scrap % on issue ───────────────────────────

    @Test
    void issueToProduction_scrapPercent_inflatesIssuedQuantity() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        BomComponent comp = buildBomComponent();
        comp.setScrapPercent(BigDecimal.valueOf(10));

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(comp));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.issueToProduction(wo.getId());

        org.mockito.ArgumentCaptor<StockMovementRequest> captor =
                org.mockito.ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(captor.capture());

        // requiredQty 30 × (1 + 10/100) = 33, issued as a negative movement
        assertEquals(0, BigDecimal.valueOf(-33).compareTo(captor.getValue().quantity()));
        assertEquals(0, BigDecimal.valueOf(33).compareTo(result.getLines().get(0).getIssuedQty()));
        // RM cost reflects the inflated issue: 33 × 50 = 1650
        assertEquals(0, BigDecimal.valueOf(1650).compareTo(result.getRawMaterialCost()));
    }

    @Test
    void issueToProduction_zeroScrapPercent_issuesNominalQuantity() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        BomComponent comp = buildBomComponent(); // scrapPercent defaults to 0

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(comp));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.issueToProduction(wo.getId());

        org.mockito.ArgumentCaptor<StockMovementRequest> captor =
                org.mockito.ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(captor.capture());
        assertEquals(0, BigDecimal.valueOf(-30).compareTo(captor.getValue().quantity()));
        assertEquals(0, BigDecimal.valueOf(1500).compareTo(result.getRawMaterialCost()));
    }

    // ── BOM Enhancements: co-products on FG receipt ──────────────────

    @Test
    void receiveFinishedGoods_withCoProducts_splitsCostAndReceivesCoProduct() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        UUID coProductItemId = UUID.randomUUID();
        BomCoProduct cp = BomCoProduct.builder()
                .parentItemId(fgItemId)
                .coProductItemId(coProductItemId)
                .quantityPerUnit(BigDecimal.valueOf(2))
                .costAllocationPercent(BigDecimal.valueOf(20))
                .build();
        cp.setOrgId(orgId);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(bomCoProductRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(cp));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // Partial receipt of 5/10 keeps the WO IN_PROGRESS (no completion journal)
        WorkOrder result = service.receiveFinishedGoods(wo.getId(), BigDecimal.valueOf(5));

        org.mockito.ArgumentCaptor<StockMovementRequest> captor =
                org.mockito.ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService, times(2)).recordMovement(captor.capture());

        StockMovementRequest fgMove = captor.getAllValues().get(0);
        StockMovementRequest cpMove = captor.getAllValues().get(1);

        // Main FG keeps 80% of cost: 1500 × 0.8 / 10 = 120 per unit
        assertEquals(fgItemId, fgMove.itemId());
        assertEquals(MovementType.PRODUCTION_RECEIVE, fgMove.movementType());
        assertEquals(0, BigDecimal.valueOf(5).compareTo(fgMove.quantity()));
        assertEquals(0, BigDecimal.valueOf(120).compareTo(fgMove.unitCost()));
        assertEquals(0, BigDecimal.valueOf(120).compareTo(result.getUnitCost()));

        // Co-product: 5 × 2 = 10 units @ 1500 × 0.2 / (10 × 2) = 15 per unit
        assertEquals(coProductItemId, cpMove.itemId());
        assertEquals(MovementType.PRODUCTION_RECEIVE, cpMove.movementType());
        assertEquals(0, BigDecimal.valueOf(10).compareTo(cpMove.quantity()));
        assertEquals(0, BigDecimal.valueOf(15).compareTo(cpMove.unitCost()));
    }

    @Test
    void receiveFinishedGoods_noCoProducts_legacyCostPathUnchanged() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        // bomCoProductRepo unstubbed → empty list → pre-co-product path

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.receiveFinishedGoods(wo.getId(), BigDecimal.valueOf(5));

        org.mockito.ArgumentCaptor<StockMovementRequest> captor =
                org.mockito.ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService, times(1)).recordMovement(captor.capture());
        // Full cost on the FG: 1500 / 10 = 150 per unit, exactly as before
        assertEquals(0, BigDecimal.valueOf(150).compareTo(captor.getValue().unitCost()));
        assertEquals(0, BigDecimal.valueOf(150).compareTo(result.getUnitCost()));
    }

    // ── BOM Enhancements: alternate substitution ─────────────────────

    @Test
    void substituteWorkOrderLine_registeredAlternate_swapsItemAndReprices() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        var line = wo.getLines().get(0);
        line.setId(UUID.randomUUID());

        BomComponent comp = buildBomComponent();
        comp.setId(UUID.randomUUID());

        UUID alternateItemId = UUID.randomUUID();
        Item alternate = Item.builder()
                .sku("RM-ALT").name("Alternate Material")
                .itemType(ItemType.GOODS)
                .purchasePrice(BigDecimal.valueOf(60))
                .salePrice(BigDecimal.ZERO)
                .build();
        alternate.setId(alternateItemId);
        alternate.setOrgId(orgId);

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(comp));
        when(bomAlternateRepo.existsByOrgIdAndBomComponentIdAndAlternateItemIdAndIsDeletedFalse(
                orgId, comp.getId(), alternateItemId)).thenReturn(true);
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(alternateItemId, orgId))
                .thenReturn(Optional.of(alternate));
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.substituteWorkOrderLine(wo.getId(), line.getId(), alternateItemId);

        assertEquals(alternateItemId, result.getLines().get(0).getItemId());
        assertEquals(0, BigDecimal.valueOf(60).compareTo(result.getLines().get(0).getUnitCost()));
        // 30 × 60 = 1800
        assertEquals(0, BigDecimal.valueOf(1800).compareTo(result.getLines().get(0).getLineCost()));
        assertEquals(0, BigDecimal.valueOf(1800).compareTo(result.getRawMaterialCost()));
    }

    @Test
    void substituteWorkOrderLine_unregisteredAlternate_throws() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        var line = wo.getLines().get(0);
        line.setId(UUID.randomUUID());

        BomComponent comp = buildBomComponent();
        comp.setId(UUID.randomUUID());

        UUID alternateItemId = UUID.randomUUID();

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(comp));
        when(bomAlternateRepo.existsByOrgIdAndBomComponentIdAndAlternateItemIdAndIsDeletedFalse(
                orgId, comp.getId(), alternateItemId)).thenReturn(false);

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.substituteWorkOrderLine(wo.getId(), line.getId(), alternateItemId));
        assertEquals("MFG_ALTERNATE_NOT_REGISTERED", ex.getErrorCode());
        verify(workOrderRepo, never()).save(any());
    }

    @Test
    void substituteWorkOrderLine_notDraft_throws() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        var line = wo.getLines().get(0);
        line.setId(UUID.randomUUID());

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.substituteWorkOrderLine(wo.getId(), line.getId(), UUID.randomUUID()));
        assertEquals("MFG_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void addBomAlternate_sameAsPrimary_throws() {
        BomComponent comp = buildBomComponent();
        comp.setId(UUID.randomUUID());
        Item rm = buildRawMaterial();

        when(bomComponentRepo.findByIdAndOrgIdAndIsDeletedFalse(comp.getId(), orgId))
                .thenReturn(Optional.of(comp));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId))
                .thenReturn(Optional.of(rm));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.addBomAlternate(comp.getId(), rmItemId, 1, null));
        assertEquals("MFG_ALTERNATE_SAME_AS_PRIMARY", ex.getErrorCode());
        verify(bomAlternateRepo, never()).save(any());
    }

    @Test
    void addBomAlternate_happyPath_persists() {
        BomComponent comp = buildBomComponent();
        comp.setId(UUID.randomUUID());

        UUID alternateItemId = UUID.randomUUID();
        Item alternate = Item.builder()
                .sku("RM-ALT").name("Alternate Material")
                .itemType(ItemType.GOODS)
                .purchasePrice(BigDecimal.valueOf(60))
                .salePrice(BigDecimal.ZERO)
                .build();
        alternate.setId(alternateItemId);
        alternate.setOrgId(orgId);

        when(bomComponentRepo.findByIdAndOrgIdAndIsDeletedFalse(comp.getId(), orgId))
                .thenReturn(Optional.of(comp));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(alternateItemId, orgId))
                .thenReturn(Optional.of(alternate));
        when(bomAlternateRepo.existsByOrgIdAndBomComponentIdAndAlternateItemIdAndIsDeletedFalse(
                orgId, comp.getId(), alternateItemId)).thenReturn(false);
        when(bomAlternateRepo.save(any(BomAlternate.class))).thenAnswer(inv -> {
            BomAlternate row = inv.getArgument(0);
            row.setId(UUID.randomUUID());
            return row;
        });

        BomAlternate saved = service.addBomAlternate(comp.getId(), alternateItemId, 2, "supplier B");

        assertNotNull(saved.getId());
        assertEquals(comp.getId(), saved.getBomComponentId());
        assertEquals(alternateItemId, saved.getAlternateItemId());
        assertEquals(2, saved.getPriority());
    }

    // ── BOM Enhancements: cost roll-up ───────────────────────────────

    @Test
    void getBomCostRollup_recursesThroughLevelsWithScrapInflation() {
        UUID subAssemblyId = UUID.randomUUID();
        UUID leafId = UUID.randomUUID();

        Item root = buildCompositeItem();
        Item sub = Item.builder()
                .sku("SUB-001").name("Sub Assembly")
                .itemType(ItemType.COMPOSITE)
                .phantom(true)
                .purchasePrice(BigDecimal.ZERO)
                .salePrice(BigDecimal.ZERO)
                .build();
        sub.setId(subAssemblyId);
        sub.setOrgId(orgId);
        Item leaf = Item.builder()
                .sku("LEAF-001").name("Leaf Material")
                .itemType(ItemType.GOODS)
                .purchasePrice(BigDecimal.TEN)
                .salePrice(BigDecimal.ZERO)
                .build();
        leaf.setId(leafId);
        leaf.setOrgId(orgId);

        BomComponent rootComp = BomComponent.builder()
                .parentItemId(fgItemId).childItemId(subAssemblyId)
                .quantity(BigDecimal.valueOf(2)).build();
        rootComp.setOrgId(orgId);
        BomComponent subComp = BomComponent.builder()
                .parentItemId(subAssemblyId).childItemId(leafId)
                .quantity(BigDecimal.valueOf(3))
                .scrapPercent(BigDecimal.valueOf(10)).build();
        subComp.setOrgId(orgId);

        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(root));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(subAssemblyId, orgId)).thenReturn(Optional.of(sub));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(leafId, orgId)).thenReturn(Optional.of(leaf));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(rootComp));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, subAssemblyId))
                .thenReturn(List.of(subComp));

        Map<String, Object> result = service.getBomCostRollup(fgItemId);

        // Leaf: 3 × 1.10 = 3.3 effective × ₹10 = ₹33.00 per sub-assembly unit
        // Root: 2 sub-assemblies × ₹33.00 = ₹66.00
        assertEquals(0, new BigDecimal("66.00").compareTo((BigDecimal) result.get("totalCost")));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> children = (List<Map<String, Object>>) result.get("children");
        assertEquals(1, children.size());
        Map<String, Object> subNode = children.get(0);
        assertEquals(0, new BigDecimal("33.00").compareTo((BigDecimal) subNode.get("unitCost")));
        assertEquals(0, new BigDecimal("66.00").compareTo((BigDecimal) subNode.get("extendedCost")));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> grandChildren = (List<Map<String, Object>>) subNode.get("children");
        assertEquals(1, grandChildren.size());
        Map<String, Object> leafNode = grandChildren.get(0);
        assertEquals(0, new BigDecimal("3.3").compareTo((BigDecimal) leafNode.get("effectiveQuantity")));
        assertEquals(0, new BigDecimal("33.00").compareTo((BigDecimal) leafNode.get("extendedCost")));
    }

    private WorkOrder createTestWorkOrder(String status) {
        var line = com.katasticho.erp.manufacturing.entity.WorkOrderLine.builder()
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

    // ─── Shop-floor lookup ───

    @Test
    void getWorkOrderByNumber_returnsWoForScanInput() {
        WorkOrder wo = createTestWorkOrder("DRAFT");
        when(workOrderRepo
                .findByOrgIdAndWorkOrderNumberIgnoreCaseAndIsDeletedFalse(orgId, "WO-00001"))
                .thenReturn(java.util.Optional.of(wo));

        WorkOrder result = service.getWorkOrderByNumber("WO-00001");

        assertEquals(wo.getId(), result.getId());
        assertEquals("WO-00001", result.getWorkOrderNumber());
    }

    @Test
    void getWorkOrderByNumber_unknownNumber_throwsNotFound() {
        when(workOrderRepo
                .findByOrgIdAndWorkOrderNumberIgnoreCaseAndIsDeletedFalse(orgId, "WO-99999"))
                .thenReturn(java.util.Optional.empty());

        assertThrows(BusinessException.class,
                () -> service.getWorkOrderByNumber("WO-99999"));
    }
}
