package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.*;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TransferOrderServiceTest {

    @Mock private TransferOrderRepository transferOrderRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private StockBatchRepository batchRepository;
    @Mock private StockMovementRepository stockMovementRepository;
    @Mock private InventoryService inventoryService;

    private TransferOrderService service;
    private UUID orgId;
    private UUID userId;
    private UUID fromWhId;
    private UUID toWhId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        fromWhId = UUID.randomUUID();
        toWhId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        service = new TransferOrderService(
                transferOrderRepository, warehouseRepository,
                itemRepository, stockBalanceRepository,
                batchRepository, stockMovementRepository, inventoryService);
        // ship/receive/cancel now use the pessimistic-locked finder — delegate it
        // to the plain finder so per-test stubs on the latter flow through.
        lenient().when(transferOrderRepository.findByIdAndOrgIdForUpdate(any(), any()))
                .thenAnswer(inv -> transferOrderRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(inv.getArgument(0), inv.getArgument(1)));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void create_happyPath() {
        Warehouse fromWh = makeWarehouse(fromWhId, "Main");
        Warehouse toWh = makeWarehouse(toWhId, "Branch");
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(fromWhId, orgId)).thenReturn(Optional.of(fromWh));
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(toWhId, orgId)).thenReturn(Optional.of(toWh));
        when(transferOrderRepository.nextSequence(eq(orgId), anyString())).thenReturn(1);

        UUID itemId = UUID.randomUUID();
        Item item = makeItem(itemId, "Widget");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId)).thenReturn(Optional.of(item));
        when(transferOrderRepository.save(any(TransferOrder.class))).thenAnswer(inv -> {
            TransferOrder to = inv.getArgument(0);
            to.setId(UUID.randomUUID());
            return to;
        });
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList())).thenReturn(List.of(item));

        CreateTransferOrderRequest req = new CreateTransferOrderRequest(
                fromWhId, toWhId, LocalDate.now(), "Test",
                List.of(new TransferOrderLineRequest(itemId, null, new BigDecimal("10"), null)));

        TransferOrderResponse response = service.create(req);

        assertEquals("DRAFT", response.status());
        assertEquals(1, response.lineCount());
        assertEquals("Main", response.fromWarehouseName());
        assertEquals("Branch", response.toWarehouseName());
    }

    @Test
    void create_rejectsSameWarehouse() {
        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.create(new CreateTransferOrderRequest(
                        fromWhId, fromWhId, null, null, List.of())));
        assertEquals("TO_SAME_WAREHOUSE", ex.getErrorCode());
    }

    @Test
    void ship_deductsStockFromSource() {
        TransferOrder to = buildDraftTO();
        when(transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(to.getId(), orgId))
                .thenReturn(Optional.of(to));

        UUID itemId = to.getLines().get(0).getItemId();
        StockBalance bal = StockBalance.builder().quantityOnHand(new BigDecimal("50")).build();
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, fromWhId))
                .thenReturn(Optional.of(bal));
        when(inventoryService.recordMovement(any())).thenReturn(new StockMovement());
        when(transferOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(warehouseRepository.findById(fromWhId)).thenReturn(Optional.of(makeWarehouse(fromWhId, "Main")));
        when(warehouseRepository.findById(toWhId)).thenReturn(Optional.of(makeWarehouse(toWhId, "Branch")));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList())).thenReturn(List.of());

        TransferOrderResponse response = service.ship(to.getId());

        assertEquals("IN_TRANSIT", response.status());

        ArgumentCaptor<StockMovementRequest> captor = ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(captor.capture());
        StockMovementRequest req = captor.getValue();
        assertEquals(MovementType.TRANSFER_OUT, req.movementType());
        assertEquals(new BigDecimal("-10"), req.quantity());
        assertEquals(fromWhId, req.warehouseId());
    }

    @Test
    void ship_insufficientStock_throws() {
        TransferOrder to = buildDraftTO();
        when(transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(to.getId(), orgId))
                .thenReturn(Optional.of(to));

        UUID itemId = to.getLines().get(0).getItemId();
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, fromWhId))
                .thenReturn(Optional.empty());
        when(itemRepository.findById(itemId)).thenReturn(Optional.of(makeItem(itemId, "Widget")));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.ship(to.getId()));
        assertEquals("TO_INSUFFICIENT_STOCK", ex.getErrorCode());
    }

    @Test
    void receive_addsStockToDestination() {
        TransferOrder to = buildDraftTO();
        to.setStatus("IN_TRANSIT");
        when(transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(to.getId(), orgId))
                .thenReturn(Optional.of(to));
        when(inventoryService.recordMovement(any())).thenReturn(new StockMovement());
        when(transferOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(warehouseRepository.findById(fromWhId)).thenReturn(Optional.of(makeWarehouse(fromWhId, "Main")));
        when(warehouseRepository.findById(toWhId)).thenReturn(Optional.of(makeWarehouse(toWhId, "Branch")));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList())).thenReturn(List.of());

        TransferOrderResponse response = service.receive(to.getId());

        assertEquals("RECEIVED", response.status());

        ArgumentCaptor<StockMovementRequest> captor = ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(captor.capture());
        StockMovementRequest req = captor.getValue();
        assertEquals(MovementType.TRANSFER_IN, req.movementType());
        assertEquals(new BigDecimal("10"), req.quantity());
        assertEquals(toWhId, req.warehouseId());
    }

    @Test
    void cancel_inTransit_reversesStockDeduction() {
        TransferOrder to = buildDraftTO();
        to.setStatus("IN_TRANSIT");
        when(transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(to.getId(), orgId))
                .thenReturn(Optional.of(to));
        when(transferOrderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.cancel(to.getId());

        assertEquals("CANCELLED", to.getStatus());
        // Cancellation now unwinds the TRANSFER_OUT leg via append-only REVERSAL
        // rows keyed to the transfer reference (never a re-recorded TRANSFER_IN),
        // matching the ledger's append-only correction rule.
        verify(inventoryService).reverseMovementsByReference(
                eq(orgId), eq(ReferenceType.STOCK_TRANSFER), eq(to.getId()),
                eq(MovementType.TRANSFER_OUT), anyString());
        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void cancel_received_throws() {
        TransferOrder to = buildDraftTO();
        to.setStatus("RECEIVED");
        when(transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(to.getId(), orgId))
                .thenReturn(Optional.of(to));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.cancel(to.getId()));
        assertEquals("TO_ALREADY_RECEIVED", ex.getErrorCode());
    }

    private TransferOrder buildDraftTO() {
        TransferOrder to = TransferOrder.builder()
                .transferNumber("TO-2026-000001")
                .fromWarehouseId(fromWhId)
                .toWarehouseId(toWhId)
                .transferDate(LocalDate.now())
                .build();
        to.setId(UUID.randomUUID());
        to.setOrgId(orgId);

        TransferOrderLine line = TransferOrderLine.builder()
                .itemId(UUID.randomUUID())
                .quantity(new BigDecimal("10"))
                .build();
        line.setId(UUID.randomUUID());
        to.addLine(line);

        return to;
    }

    private Warehouse makeWarehouse(UUID id, String name) {
        Warehouse wh = new Warehouse();
        wh.setId(id);
        wh.setName(name);
        return wh;
    }

    private Item makeItem(UUID id, String name) {
        Item item = Item.builder().build();
        item.setId(id);
        item.setOrgId(orgId);
        item.setName(name);
        item.setSku("SKU-" + name.toUpperCase());
        return item;
    }
}
