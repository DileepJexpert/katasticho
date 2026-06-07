package com.katasticho.erp.manufacturing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.BomComponent;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.BomComponentRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
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
                salesOrderRepo, warehouseRepo);
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
    void issueToProduction_draftOrder_deductsStock() {
        WorkOrder wo = createTestWorkOrder("DRAFT");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.issueToProduction(wo.getId());

        assertEquals("IN_PROGRESS", result.getStatus());
        assertNotNull(result.getActualStartDate());
        assertEquals("ISSUED", result.getLines().get(0).getStatus());
        verify(inventoryService, times(1)).recordMovement(any());
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
    void receiveFinishedGoods_fullQuantity_completesOrder() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.receiveFinishedGoods(wo.getId(), BigDecimal.TEN);

        assertEquals("COMPLETED", result.getStatus());
        assertEquals(0, BigDecimal.TEN.compareTo(result.getQuantityProduced()));
        assertNotNull(result.getActualEndDate());
        verify(inventoryService).recordMovement(any());
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
    void cancelWorkOrder_inProgress_reversesStock() {
        WorkOrder wo = createTestWorkOrder("IN_PROGRESS");
        wo.getLines().get(0).setIssuedQty(BigDecimal.valueOf(30));

        when(workOrderRepo.findByIdAndOrgIdAndIsDeletedFalse(wo.getId(), orgId))
                .thenReturn(Optional.of(wo));
        when(inventoryService.recordMovement(any())).thenReturn(null);
        when(workOrderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        WorkOrder result = service.cancelWorkOrder(wo.getId());

        assertEquals("CANCELLED", result.getStatus());
        assertEquals("CANCELLED", result.getLines().get(0).getStatus());
        verify(inventoryService, times(1)).recordMovement(any());
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
}
