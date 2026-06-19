package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.accounting.posting.ManufacturingWipPostingRule;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.*;
import com.katasticho.erp.manufacturing.repository.*;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.service.PurchaseOrderService;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import com.katasticho.erp.supplychain.entity.DemandForecast;
import com.katasticho.erp.supplychain.entity.ItemSupplier;
import com.katasticho.erp.supplychain.entity.ReorderPolicy;
import com.katasticho.erp.supplychain.repository.DemandForecastRepository;
import com.katasticho.erp.supplychain.repository.ItemSupplierRepository;
import com.katasticho.erp.supplychain.repository.ReorderPolicyRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MrpServiceTest {

    // ── MrpService deps ──────────────────────────────────────────────────────
    @Mock private MrpRunRepository mrpRunRepo;
    @Mock private MrpDemandRepository mrpDemandRepo;
    @Mock private MrpSupplyRepository mrpSupplyRepo;
    @Mock private PlannedOrderRepository plannedOrderRepo;
    @Mock private SalesOrderRepository salesOrderRepo;
    @Mock private ItemRepository itemRepo;
    @Mock private StockBalanceRepository stockBalanceRepo;
    @Mock private BomComponentRepository bomComponentRepo;
    @Mock private ItemSupplierRepository itemSupplierRepo;
    @Mock private ReorderPolicyRepository reorderPolicyRepo;
    @Mock private DemandForecastRepository forecastRepo;
    @Mock private WorkOrderRepository workOrderRepo;

    // ── ManufacturingService (used for convertPlannedToWO) ───────────────────
    @Mock private WorkOrderLineRepository workOrderLineRepo;
    @Mock private InventoryService inventoryService;
    @Mock private WarehouseRepository warehouseRepo;
    @Mock private JournalService journalService;
    @Mock private ManufacturingWipPostingRule wipPostingRule;
    @Mock private ProductionCostSummaryRepository costSummaryRepo;
    @Mock private com.katasticho.erp.inventory.repository.BomAlternateRepository bomAlternateRepo;
    @Mock private com.katasticho.erp.inventory.repository.BomCoProductRepository bomCoProductRepo;
    @Mock private com.katasticho.erp.common.workflow.ApprovalWorkflowService approvalWorkflowService;
    @Mock private com.katasticho.erp.manufacturing.repository.ProductionScrapRepository productionScrapRepo;
    @Mock private com.katasticho.erp.manufacturing.repository.ScrapReasonCodeRepository scrapReasonCodeRepo;

    // ── PurchaseOrderService (used for convertPlannedToPO) ───────────────────
    @Mock private PurchaseOrderService purchaseOrderService;

    private ManufacturingService manufacturingService;
    private MrpService mrpService;

    private final UUID orgId     = UUID.randomUUID();
    private final UUID userId    = UUID.randomUUID();
    private final UUID fgItemId  = UUID.randomUUID();
    private final UUID rmItemId  = UUID.randomUUID();
    private final UUID warehouseId = UUID.randomUUID();
    private final UUID supplierId  = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        manufacturingService = new ManufacturingService(
                workOrderRepo, workOrderLineRepo, bomComponentRepo, itemRepo, inventoryService,
                salesOrderRepo, warehouseRepo, journalService, wipPostingRule, costSummaryRepo,
                bomAlternateRepo, bomCoProductRepo, approvalWorkflowService,
                productionScrapRepo, scrapReasonCodeRepo, null, null, null, null);

        mrpService = new MrpService(
                mrpRunRepo, mrpDemandRepo, mrpSupplyRepo, plannedOrderRepo,
                salesOrderRepo, itemRepo, stockBalanceRepo, bomComponentRepo,
                itemSupplierRepo, reorderPolicyRepo, forecastRepo, workOrderRepo,
                manufacturingService, purchaseOrderService);

        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private MrpRun savedRun() {
        MrpRun run = MrpRun.builder()
                .runDate(LocalDate.now())
                .status("RUNNING")
                .horizonDays(90)
                .build();
        run.setId(UUID.randomUUID());
        run.setOrgId(orgId);
        return run;
    }

    private Item compositeItem() {
        Item item = Item.builder()
                .sku("FG-001").name("Finished Good")
                .itemType(ItemType.COMPOSITE)
                .purchasePrice(BigDecimal.ZERO)
                .salePrice(BigDecimal.valueOf(500))
                .build();
        item.setId(fgItemId);
        item.setOrgId(orgId);
        return item;
    }

    private Item purchasedItem() {
        Item item = Item.builder()
                .sku("RM-001").name("Raw Material")
                .itemType(ItemType.GOODS)
                .purchasePrice(BigDecimal.valueOf(50))
                .salePrice(BigDecimal.ZERO)
                .build();
        item.setId(rmItemId);
        item.setOrgId(orgId);
        return item;
    }

    private BomComponent bomLine(UUID parent, UUID child, BigDecimal qty) {
        BomComponent c = BomComponent.builder()
                .parentItemId(parent)
                .childItemId(child)
                .quantity(qty)
                .build();
        c.setId(UUID.randomUUID());
        c.setOrgId(orgId);
        return c;
    }

    private SalesOrder openSO(UUID itemId, BigDecimal qty) {
        SalesOrderLine line = SalesOrderLine.builder()
                .itemId(itemId)
                .quantity(qty)
                .quantityShipped(BigDecimal.ZERO)
                .rate(BigDecimal.valueOf(100))
                .amount(qty.multiply(BigDecimal.valueOf(100)))
                .build();
        line.setId(UUID.randomUUID());

        SalesOrder so = SalesOrder.builder()
                .salesorderNumber("SO-001")
                .contactId(UUID.randomUUID())
                .orderDate(LocalDate.now())
                .expectedShipmentDate(LocalDate.now().plusDays(10))
                .status("CONFIRMED")
                .lines(new ArrayList<>(List.of(line)))
                .build();
        so.setId(UUID.randomUUID());
        so.setOrgId(orgId);
        line.setSalesOrder(so);
        return so;
    }

    private PlannedOrder savedPlannedOrder(String orderType, UUID itemId, UUID supplierId) {
        PlannedOrder po = PlannedOrder.builder()
                .orderType(orderType)
                .itemId(itemId)
                .plannedQty(BigDecimal.TEN)
                .leadTimeDays(7)
                .supplierId(supplierId)
                .status("PLANNED")
                .plannedStartDate(LocalDate.now())
                .plannedEndDate(LocalDate.now().plusDays(7))
                .build();
        po.setId(UUID.randomUUID());
        po.setOrgId(orgId);
        // set mrpRun id for reference
        MrpRun dummyRun = MrpRun.builder().runDate(LocalDate.now()).horizonDays(90).build();
        dummyRun.setId(UUID.randomUUID());
        dummyRun.setOrgId(orgId);
        po.setMrpRun(dummyRun);
        return po;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    /**
     * Test 1: runMrp with a single open SO creates demand and a PLANNED purchase order.
     */
    @Test
    void runMrp_withSoDemand_createsPlannedPurchaseOrder() {
        Item rm = purchasedItem();
        SalesOrder so = openSO(rmItemId, BigDecimal.valueOf(20));

        MrpRun run = savedRun();
        when(mrpRunRepo.save(any())).thenReturn(run);
        when(salesOrderRepo.findPendingDispatch(orgId)).thenReturn(List.of(so));
        when(forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                any(), any(), any())).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId)).thenReturn(List.of());
        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(any(), any())).thenReturn(List.of());
        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, rmItemId))
                .thenReturn(List.of()); // not composite
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(mrpDemandRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        MrpRun result = mrpService.runMrp(90);

        assertEquals("COMPLETED", run.getStatus());
        verify(mrpDemandRepo, atLeastOnce()).save(any(MrpDemand.class));
        verify(plannedOrderRepo, atLeastOnce()).save(argThat(p ->
                "PURCHASE".equals(p.getOrderType()) && rmItemId.equals(p.getItemId())));
    }

    /**
     * Test 2: runMrp with a composite item creates PRODUCTION planned order.
     */
    @Test
    void runMrp_withCompositeDemand_createsProductionPlannedOrder() {
        Item fg = compositeItem();
        Item rm = purchasedItem();
        SalesOrder so = openSO(fgItemId, BigDecimal.valueOf(5));
        BomComponent bom = bomLine(fgItemId, rmItemId, BigDecimal.valueOf(3));

        MrpRun run = savedRun();
        when(mrpRunRepo.save(any())).thenReturn(run);
        when(salesOrderRepo.findPendingDispatch(orgId)).thenReturn(List.of(so));
        when(forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                any(), any(), any())).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId)).thenReturn(List.of());
        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(any(), any())).thenReturn(List.of());

        // FG item setup
        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, fgItemId))
                .thenReturn(Optional.empty());
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(bom));

        // RM item (child from explosion)
        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, rmItemId))
                .thenReturn(List.of());
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());

        when(mrpDemandRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        mrpService.runMrp(90);

        // Should create a PRODUCTION planned order for the FG item
        verify(plannedOrderRepo, atLeastOnce()).save(argThat(p ->
                "PRODUCTION".equals(p.getOrderType()) && fgItemId.equals(p.getItemId())));
    }

    /**
     * Test 3: BOM explosion creates component demand for child items.
     */
    @Test
    void runMrp_bomExplosion_createsDemandForComponents() {
        Item fg = compositeItem();
        Item rm = purchasedItem();
        // FG demand: 5 units
        SalesOrder so = openSO(fgItemId, BigDecimal.valueOf(5));
        // BOM: 3 RM per FG → 15 RM needed
        BomComponent bom = bomLine(fgItemId, rmItemId, BigDecimal.valueOf(3));

        MrpRun run = savedRun();
        when(mrpRunRepo.save(any())).thenReturn(run);
        when(salesOrderRepo.findPendingDispatch(orgId)).thenReturn(List.of(so));
        when(forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                any(), any(), any())).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId)).thenReturn(List.of());
        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(any(), any())).thenReturn(List.of());

        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(bom));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, rmItemId))
                .thenReturn(List.of());
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(mrpDemandRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        mrpService.runMrp(90);

        // Demand should be recorded for both FG (from SO) and RM (from BOM explosion)
        ArgumentCaptor<MrpDemand> demandCaptor = ArgumentCaptor.forClass(MrpDemand.class);
        verify(mrpDemandRepo, atLeast(2)).save(demandCaptor.capture());

        List<MrpDemand> allDemands = demandCaptor.getAllValues();
        boolean hasSoDemand = allDemands.stream().anyMatch(d ->
                "SALES_ORDER".equals(d.getSourceType()) && fgItemId.equals(d.getItemId()));
        boolean hasExplosionDemand = allDemands.stream().anyMatch(d ->
                "MRP_EXPLOSION".equals(d.getSourceType()) && rmItemId.equals(d.getItemId()));

        assertTrue(hasSoDemand, "Should create SO demand for FG");
        assertTrue(hasExplosionDemand, "Should create explosion demand for RM component");
    }

    /**
     * Test 3b: Phantom composites get NO PRODUCTION planned order — their
     * components become demand directly (and roll up to PURCHASE orders).
     */
    @Test
    void runMrp_phantomComposite_skipsProductionOrderAndExplodesComponents() {
        Item phantomFg = compositeItem();
        phantomFg.setPhantom(true);
        Item rm = purchasedItem();
        SalesOrder so = openSO(fgItemId, BigDecimal.valueOf(5));
        BomComponent bom = bomLine(fgItemId, rmItemId, BigDecimal.valueOf(2));

        MrpRun run = savedRun();
        when(mrpRunRepo.save(any())).thenReturn(run);
        when(salesOrderRepo.findPendingDispatch(orgId)).thenReturn(List.of(so));
        when(forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                any(), any(), any())).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId)).thenReturn(List.of());
        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(any(), any())).thenReturn(List.of());

        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(phantomFg));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(bom));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, rmItemId))
                .thenReturn(List.of());
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(mrpDemandRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        mrpService.runMrp(90);

        // No PRODUCTION planned order for the phantom itself
        verify(plannedOrderRepo, never()).save(argThat(p -> fgItemId.equals(p.getItemId())));
        // Components became demand directly: 5 × 2 = 10 RM → PURCHASE order
        verify(plannedOrderRepo, atLeastOnce()).save(argThat(p ->
                "PURCHASE".equals(p.getOrderType())
                        && rmItemId.equals(p.getItemId())
                        && BigDecimal.TEN.compareTo(p.getPlannedQty()) == 0));
    }

    /**
     * Test 4: Net requirement = demand - supply (on-hand stock reduces planned qty).
     */
    @Test
    void runMrp_netRequirementDeductedByOnHandStock() {
        Item rm = purchasedItem();
        // Demand: 20 units from SO
        SalesOrder so = openSO(rmItemId, BigDecimal.valueOf(20));

        // On-hand stock: 15 units available
        StockBalance balance = StockBalance.builder()
                .orgId(orgId)
                .itemId(rmItemId)
                .warehouseId(warehouseId)
                .quantityOnHand(BigDecimal.valueOf(15))
                .reservedQty(BigDecimal.ZERO)
                .build();
        balance.setId(UUID.randomUUID());

        MrpRun run = savedRun();
        when(mrpRunRepo.save(any())).thenReturn(run);
        when(salesOrderRepo.findPendingDispatch(orgId)).thenReturn(List.of(so));
        when(forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                any(), any(), any())).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId)).thenReturn(List.of(balance));
        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(any(), any())).thenReturn(List.of());
        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, rmItemId))
                .thenReturn(List.of());
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(mrpDemandRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(mrpSupplyRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        mrpService.runMrp(90);

        // Net requirement = 20 - 15 = 5 → planned order for 5 units
        ArgumentCaptor<PlannedOrder> poCaptor = ArgumentCaptor.forClass(PlannedOrder.class);
        verify(plannedOrderRepo, atLeastOnce()).save(poCaptor.capture());
        PlannedOrder planned = poCaptor.getAllValues().stream()
                .filter(p -> rmItemId.equals(p.getItemId()))
                .findFirst().orElseThrow();
        assertEquals(0, BigDecimal.valueOf(5).compareTo(planned.getPlannedQty()),
                "Net requirement should be demand(20) - supply(15) = 5");
    }

    /**
     * Test 5: When supply >= demand, no planned order is created.
     */
    @Test
    void runMrp_sufficientStock_noPlannedOrderCreated() {
        SalesOrder so = openSO(rmItemId, BigDecimal.valueOf(10));

        // On-hand stock: 50 units — more than enough
        StockBalance balance = StockBalance.builder()
                .orgId(orgId).itemId(rmItemId).warehouseId(warehouseId)
                .quantityOnHand(BigDecimal.valueOf(50)).reservedQty(BigDecimal.ZERO).build();
        balance.setId(UUID.randomUUID());

        MrpRun run = savedRun();
        when(mrpRunRepo.save(any())).thenReturn(run);
        when(salesOrderRepo.findPendingDispatch(orgId)).thenReturn(List.of(so));
        when(forecastRepo.findByOrgIdAndForecastMonthBetweenAndIsDeletedFalseOrderByForecastMonth(
                any(), any(), any())).thenReturn(List.of());
        when(stockBalanceRepo.findByOrgIdOrderByLastMovementAtDesc(orgId)).thenReturn(List.of(balance));
        when(workOrderRepo.findByOrgIdAndStatusInAndIsDeletedFalse(any(), any())).thenReturn(List.of());
        when(reorderPolicyRepo.findByOrgIdAndItemIdAndWarehouseIdIsNullAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.empty());
        when(mrpDemandRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(mrpSupplyRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        mrpService.runMrp(90);

        // No planned orders should be created
        verify(plannedOrderRepo, never()).save(any());
    }

    /**
     * Test 6: getMrpRun returns run by id.
     */
    @Test
    void getMrpRun_found_returnsRun() {
        MrpRun run = savedRun();
        when(mrpRunRepo.findByIdAndOrgIdAndIsDeletedFalse(run.getId(), orgId))
                .thenReturn(Optional.of(run));

        MrpRun result = mrpService.getMrpRun(run.getId());
        assertNotNull(result);
        assertEquals(run.getId(), result.getId());
    }

    /**
     * Test 7: convertPlannedToPO creates a PO and marks planned order as CONVERTED.
     */
    @Test
    void convertPlannedToPO_purchaseType_createsPo() {
        PlannedOrder planned = savedPlannedOrder("PURCHASE", rmItemId, supplierId);

        ItemSupplier itemSupplier = ItemSupplier.builder()
                .itemId(rmItemId).supplierId(supplierId)
                .leadTimeDays(7).unitPrice(BigDecimal.valueOf(50))
                .preferred(true).build();
        itemSupplier.setId(UUID.randomUUID());
        itemSupplier.setOrgId(orgId);

        PurchaseOrderResponse poResponse = new PurchaseOrderResponse(
                UUID.randomUUID(), orgId, supplierId, "Test Supplier",
                "PO-00001", "DRAFT", LocalDate.now(), LocalDate.now().plusDays(7),
                null, null, BigDecimal.valueOf(500), List.of(), Instant.now());

        when(plannedOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(planned.getId(), orgId))
                .thenReturn(Optional.of(planned));
        when(itemSupplierRepo.findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(orgId, rmItemId))
                .thenReturn(Optional.of(itemSupplier));
        when(purchaseOrderService.create(any(PurchaseOrderRequest.class))).thenReturn(poResponse);
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlannedOrder result = mrpService.convertPlannedToPO(planned.getId());

        assertEquals("CONVERTED", result.getStatus());
        assertEquals(poResponse.id(), result.getPurchaseOrderId());
        verify(purchaseOrderService).create(any(PurchaseOrderRequest.class));
    }

    /**
     * Test 8: convertPlannedToWO creates a WO and marks planned order as CONVERTED.
     */
    @Test
    void convertPlannedToWO_productionType_createsWo() {
        PlannedOrder planned = savedPlannedOrder("PRODUCTION", fgItemId, null);
        planned.setSupplierId(null);
        planned.setWarehouseId(warehouseId);

        Item fg = compositeItem();
        BomComponent bom = bomLine(fgItemId, rmItemId, BigDecimal.valueOf(2));
        Item rm = purchasedItem();

        WorkOrder wo = WorkOrder.builder()
                .workOrderNumber("WO-00001")
                .finishedGoodId(fgItemId)
                .warehouseId(warehouseId)
                .quantityToProduce(BigDecimal.TEN)
                .status("DRAFT")
                .lines(new ArrayList<>())
                .build();
        wo.setId(UUID.randomUUID());
        wo.setOrgId(orgId);

        when(plannedOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(planned.getId(), orgId))
                .thenReturn(Optional.of(planned));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(fgItemId, orgId)).thenReturn(Optional.of(fg));
        when(bomComponentRepo.findByOrgIdAndParentItemIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, fgItemId))
                .thenReturn(List.of(bom));
        when(itemRepo.findByIdAndOrgIdAndIsDeletedFalse(rmItemId, orgId)).thenReturn(Optional.of(rm));
        when(workOrderRepo.findMaxWorkOrderNumber(orgId)).thenReturn(0);
        when(workOrderRepo.save(any())).thenReturn(wo);
        when(plannedOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlannedOrder result = mrpService.convertPlannedToWO(planned.getId());

        assertEquals("CONVERTED", result.getStatus());
        assertNotNull(result.getWorkOrderId());
        verify(workOrderRepo, atLeastOnce()).save(any(WorkOrder.class));
    }

    /**
     * Test 9: convertPlannedToPO rejects non-PURCHASE planned orders.
     */
    @Test
    void convertPlannedToPO_wrongType_throwsException() {
        PlannedOrder planned = savedPlannedOrder("PRODUCTION", fgItemId, null);

        when(plannedOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(planned.getId(), orgId))
                .thenReturn(Optional.of(planned));

        assertThrows(BusinessException.class, () -> mrpService.convertPlannedToPO(planned.getId()));
    }

    /**
     * Test 10: listMrpRuns returns runs in descending order.
     */
    @Test
    void listMrpRuns_returnsAll() {
        MrpRun run1 = savedRun();
        MrpRun run2 = savedRun();
        when(mrpRunRepo.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId))
                .thenReturn(List.of(run2, run1));

        List<MrpRun> result = mrpService.listMrpRuns();

        assertEquals(2, result.size());
    }
}
