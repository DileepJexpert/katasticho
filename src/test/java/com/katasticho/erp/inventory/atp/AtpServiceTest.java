package com.katasticho.erp.inventory.atp;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.manufacturing.entity.WorkOrder;
import com.katasticho.erp.manufacturing.repository.WorkOrderRepository;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderLineRepository;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AtpServiceTest {

    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private SalesOrderLineRepository salesOrderLineRepository;
    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private PurchaseOrderLineRepository purchaseOrderLineRepository;
    @Mock private PurchaseOrderRepository purchaseOrderRepository;
    @Mock private WorkOrderRepository workOrderRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private WarehouseRepository warehouseRepository;

    private AtpService service;
    private UUID orgId;
    private UUID itemId;
    private UUID warehouseId;
    private Item item;
    private Warehouse warehouse;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        service = new AtpService(stockBalanceRepository, salesOrderLineRepository,
                salesOrderRepository, purchaseOrderLineRepository, purchaseOrderRepository,
                workOrderRepository, itemRepository, warehouseRepository);

        item = Item.builder().build();
        item.setId(itemId);
        item.setOrgId(orgId);
        item.setName("Paracetamol 500mg");
        warehouse = new Warehouse();
        warehouse.setId(warehouseId);
        warehouse.setOrgId(orgId);
        warehouse.setName("Main");

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item));
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouseId, orgId))
                .thenReturn(Optional.of(warehouse));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void atpOk_noCommitments_andFullyOnHand_returnsOk() {
        stubBalance(new BigDecimal("100"));
        when(salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId))
                .thenReturn(List.of());
        when(purchaseOrderLineRepository.findOpenForItem(orgId, itemId))
                .thenReturn(List.of());
        when(workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(eq(orgId), anyList()))
                .thenReturn(List.of());

        AtpResponse r = service.compute(itemId, warehouseId, new BigDecimal("50"));

        assertEquals(AtpResponse.STATUS_OK, r.status());
        assertEquals(0, r.shortfall().compareTo(BigDecimal.ZERO));
        assertEquals(0, r.onHand().compareTo(new BigDecimal("100")));
        assertEquals(0, r.committed().compareTo(BigDecimal.ZERO));
        assertEquals(0, r.availableNow().compareTo(new BigDecimal("100")));
        assertNull(r.nextInflowDate());
    }

    @Test
    void atpPartial_onHandPartiallyCommitted_returnsShortfall() {
        stubBalance(new BigDecimal("100"));
        // 80 committed across two CONFIRMED SOs
        SalesOrder so1 = newSo("CONFIRMED");
        SalesOrder so2 = newSo("CONFIRMED");
        SalesOrderLine l1 = newSol(so1, new BigDecimal("60"), BigDecimal.ZERO);
        SalesOrderLine l2 = newSol(so2, new BigDecimal("20"), BigDecimal.ZERO);
        when(salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId))
                .thenReturn(List.of(l1, l2));
        when(salesOrderRepository.findAllById(any())).thenReturn(List.of(so1, so2));
        when(purchaseOrderLineRepository.findOpenForItem(orgId, itemId)).thenReturn(List.of());
        when(workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(eq(orgId), anyList()))
                .thenReturn(List.of());

        AtpResponse r = service.compute(itemId, warehouseId, new BigDecimal("50"));

        assertEquals(AtpResponse.STATUS_PARTIAL, r.status());
        assertEquals(0, r.committed().compareTo(new BigDecimal("80")));
        assertEquals(0, r.availableNow().compareTo(new BigDecimal("20")));
        assertEquals(0, r.shortfall().compareTo(new BigDecimal("30")));
    }

    @Test
    void atpBackorder_zeroOnHand_returnsBackorderWithEta() {
        stubBalance(BigDecimal.ZERO);
        when(salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId))
                .thenReturn(List.of());

        // Open PO 200 units, expected 2026-07-15
        PurchaseOrder po = newPo(warehouseId, LocalDate.of(2026, 7, 15));
        PurchaseOrderLine pol = newPol(po, new BigDecimal("200"), BigDecimal.ZERO);
        when(purchaseOrderLineRepository.findOpenForItem(orgId, itemId))
                .thenReturn(List.of(pol));
        when(purchaseOrderRepository.findAllById(any())).thenReturn(List.of(po));
        when(workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(eq(orgId), anyList()))
                .thenReturn(List.of());

        AtpResponse r = service.compute(itemId, warehouseId, new BigDecimal("50"));

        assertEquals(AtpResponse.STATUS_BACKORDER, r.status());
        assertEquals(0, r.availableNow().compareTo(BigDecimal.ZERO));
        assertEquals(0, r.shortfall().compareTo(new BigDecimal("50")));
        assertEquals(LocalDate.of(2026, 7, 15), r.nextInflowDate());
        assertEquals(0, r.openPurchaseQty().compareTo(new BigDecimal("200")));
    }

    @Test
    void openWoContributesToNextInflowDate_butNotAvailableNow() {
        stubBalance(new BigDecimal("10"));
        when(salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId))
                .thenReturn(List.of());
        when(purchaseOrderLineRepository.findOpenForItem(orgId, itemId)).thenReturn(List.of());

        WorkOrder wo = newWo(new BigDecimal("50"), BigDecimal.ZERO, LocalDate.of(2026, 7, 5));
        when(workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(eq(orgId), anyList()))
                .thenReturn(List.of(wo));

        AtpResponse r = service.compute(itemId, warehouseId, new BigDecimal("30"));

        // onHand 10, available 10 (no commit), partial for qty 30
        assertEquals(AtpResponse.STATUS_PARTIAL, r.status());
        assertEquals(0, r.availableNow().compareTo(new BigDecimal("10")));
        assertEquals(0, r.openProductionQty().compareTo(new BigDecimal("50")));
        assertEquals(LocalDate.of(2026, 7, 5), r.nextInflowDate());
    }

    @Test
    void multiSourceInflows_returnsEarliestEta() {
        stubBalance(BigDecimal.ZERO);
        when(salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId))
                .thenReturn(List.of());

        // PO 2026-08-01, WO 2026-07-05 → WO wins
        PurchaseOrder po = newPo(warehouseId, LocalDate.of(2026, 8, 1));
        PurchaseOrderLine pol = newPol(po, new BigDecimal("50"), BigDecimal.ZERO);
        when(purchaseOrderLineRepository.findOpenForItem(orgId, itemId)).thenReturn(List.of(pol));
        when(purchaseOrderRepository.findAllById(any())).thenReturn(List.of(po));

        WorkOrder wo = newWo(new BigDecimal("20"), BigDecimal.ZERO, LocalDate.of(2026, 7, 5));
        when(workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(eq(orgId), anyList()))
                .thenReturn(List.of(wo));

        AtpResponse r = service.compute(itemId, warehouseId, new BigDecimal("10"));

        assertEquals(LocalDate.of(2026, 7, 5), r.nextInflowDate());
        assertEquals(0, r.openPurchaseQty().compareTo(new BigDecimal("50")));
        assertEquals(0, r.openProductionQty().compareTo(new BigDecimal("20")));
    }

    @Test
    void negativeOnHand_isClampedAtZero() {
        // Bill-freely mode: stock_balance can hold a negative on-hand.
        stubBalance(new BigDecimal("-25"));
        when(salesOrderLineRepository.findOpenCommitmentLinesForItem(orgId, itemId))
                .thenReturn(List.of());
        when(purchaseOrderLineRepository.findOpenForItem(orgId, itemId)).thenReturn(List.of());
        when(workOrderRepository.findByOrgIdAndStatusInAndIsDeletedFalse(eq(orgId), anyList()))
                .thenReturn(List.of());

        AtpResponse r = service.compute(itemId, warehouseId, new BigDecimal("10"));

        // Customer-facing onHand never negative; availableNow clamped.
        assertEquals(0, r.onHand().compareTo(BigDecimal.ZERO));
        assertEquals(0, r.availableNow().compareTo(BigDecimal.ZERO));
        assertEquals(AtpResponse.STATUS_BACKORDER, r.status());
        assertEquals(0, r.shortfall().compareTo(new BigDecimal("10")));
    }

    @Test
    void unknownItem_throws() {
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.empty());
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.compute(itemId, warehouseId, BigDecimal.ONE));
        assertTrue(ex.getMessage().contains("Item"));
    }

    // ----- helpers ---------------------------------------------------------

    private void stubBalance(BigDecimal qty) {
        StockBalance b = StockBalance.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .quantityOnHand(qty).build();
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(b));
    }

    private SalesOrder newSo(String status) {
        SalesOrder so = new SalesOrder();
        so.setId(UUID.randomUUID());
        so.setOrgId(orgId);
        so.setStatus(status);
        return so;
    }

    private SalesOrderLine newSol(SalesOrder so, BigDecimal qty, BigDecimal shipped) {
        SalesOrderLine l = new SalesOrderLine();
        l.setId(UUID.randomUUID());
        l.setSalesOrder(so);
        l.setItemId(itemId);
        l.setQuantity(qty);
        l.setQuantityShipped(shipped);
        l.setRate(BigDecimal.ZERO);
        l.setAmount(BigDecimal.ZERO);
        return l;
    }

    private PurchaseOrder newPo(UUID warehouseId, LocalDate eta) {
        PurchaseOrder po = new PurchaseOrder();
        po.setId(UUID.randomUUID());
        po.setOrgId(orgId);
        po.setStatus("SENT");
        po.setWarehouseId(warehouseId);
        po.setExpectedDeliveryDate(eta);
        return po;
    }

    private PurchaseOrderLine newPol(PurchaseOrder po, BigDecimal qty, BigDecimal received) {
        PurchaseOrderLine pol = new PurchaseOrderLine();
        pol.setId(UUID.randomUUID());
        pol.setPoId(po.getId());
        pol.setItemId(itemId);
        pol.setQuantity(qty);
        pol.setReceivedQuantity(received);
        return pol;
    }

    private WorkOrder newWo(BigDecimal toProduce, BigDecimal produced, LocalDate plannedEnd) {
        WorkOrder wo = new WorkOrder();
        wo.setId(UUID.randomUUID());
        wo.setOrgId(orgId);
        wo.setFinishedGoodId(itemId);
        wo.setStatus("IN_PROGRESS");
        wo.setQuantityToProduce(toProduce);
        wo.setQuantityProduced(produced);
        wo.setPlannedEndDate(plannedEnd);
        return wo;
    }
}
