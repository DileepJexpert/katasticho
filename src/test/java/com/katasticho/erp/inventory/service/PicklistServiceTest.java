package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.*;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.*;
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
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PicklistServiceTest {

    @Mock private PicklistRepository picklistRepository;
    @Mock private SalesOrderRepository salesOrderRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private StockBatchRepository batchRepository;
    @Mock private RackLocationRepository rackLocationRepository;

    private PicklistService service;
    private UUID orgId;
    private UUID userId;
    private UUID whId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        whId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        service = new PicklistService(
                picklistRepository, salesOrderRepository,
                warehouseRepository, itemRepository,
                batchRepository, rackLocationRepository);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void create_happyPath() {
        SalesOrder so = buildConfirmedSO();
        UUID soLineId = so.getLines().get(0).getId();
        UUID itemId = so.getLines().get(0).getItemId();

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(so.getId(), orgId))
                .thenReturn(Optional.of(so));
        Warehouse wh = makeWarehouse(whId, "Main");
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(whId, orgId))
                .thenReturn(Optional.of(wh));
        when(picklistRepository.nextSequence(eq(orgId), anyString())).thenReturn(1);
        Item item = makeItem(itemId, "Widget");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item));
        when(picklistRepository.save(any(Picklist.class))).thenAnswer(inv -> {
            Picklist pl = inv.getArgument(0);
            pl.setId(UUID.randomUUID());
            return pl;
        });
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList()))
                .thenReturn(List.of(item));

        CreatePicklistRequest req = new CreatePicklistRequest(
                so.getId(), whId, null, "Test picklist",
                List.of(new PicklistLineRequest(soLineId, new BigDecimal("5"), null, null)));

        PicklistResponse response = service.create(req);

        assertEquals("PENDING", response.status());
        assertEquals(1, response.lineCount());
        assertEquals("Main", response.warehouseName());
    }

    @Test
    void create_rejectsDraftSO() {
        SalesOrder so = buildConfirmedSO();
        so.setStatus("DRAFT");
        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(so.getId(), orgId))
                .thenReturn(Optional.of(so));

        BusinessException ex = assertThrows(BusinessException.class, () ->
                service.create(new CreatePicklistRequest(
                        so.getId(), whId, null, null, List.of())));
        assertEquals("PL_INVALID_SO_STATUS", ex.getErrorCode());
    }

    @Test
    void create_rejectsExceedingQuantity() {
        SalesOrder so = buildConfirmedSO();
        UUID soLineId = so.getLines().get(0).getId();
        UUID itemId = so.getLines().get(0).getItemId();

        when(salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(so.getId(), orgId))
                .thenReturn(Optional.of(so));
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(whId, orgId))
                .thenReturn(Optional.of(makeWarehouse(whId, "Main")));
        when(picklistRepository.nextSequence(eq(orgId), anyString())).thenReturn(1);

        CreatePicklistRequest req = new CreatePicklistRequest(
                so.getId(), whId, null, null,
                List.of(new PicklistLineRequest(soLineId, new BigDecimal("999"), null, null)));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.create(req));
        assertEquals("PL_EXCEEDS_REMAINING", ex.getErrorCode());
    }

    @Test
    void startPicking_transitionsPendingToInProgress() {
        Picklist pl = buildPendingPicklist();
        when(picklistRepository.findByIdAndOrgIdAndIsDeletedFalse(pl.getId(), orgId))
                .thenReturn(Optional.of(pl));
        when(picklistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(salesOrderRepository.findById(any())).thenReturn(Optional.empty());
        when(warehouseRepository.findById(any())).thenReturn(Optional.of(makeWarehouse(whId, "Main")));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList())).thenReturn(List.of());

        PicklistResponse response = service.startPicking(pl.getId());

        assertEquals("IN_PROGRESS", response.status());
        assertNotNull(pl.getStartedAt());
    }

    @Test
    void startPicking_rejectsNonPending() {
        Picklist pl = buildPendingPicklist();
        pl.setStatus("IN_PROGRESS");
        when(picklistRepository.findByIdAndOrgIdAndIsDeletedFalse(pl.getId(), orgId))
                .thenReturn(Optional.of(pl));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.startPicking(pl.getId()));
        assertEquals("PL_NOT_PENDING", ex.getErrorCode());
    }

    @Test
    void complete_transitionsInProgressToCompleted() {
        Picklist pl = buildPendingPicklist();
        pl.setStatus("IN_PROGRESS");
        when(picklistRepository.findByIdAndOrgIdAndIsDeletedFalse(pl.getId(), orgId))
                .thenReturn(Optional.of(pl));
        when(picklistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(salesOrderRepository.findById(any())).thenReturn(Optional.empty());
        when(warehouseRepository.findById(any())).thenReturn(Optional.of(makeWarehouse(whId, "Main")));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList())).thenReturn(List.of());

        PicklistResponse response = service.complete(pl.getId());

        assertEquals("COMPLETED", response.status());
        assertNotNull(pl.getCompletedAt());
    }

    @Test
    void cancel_completedPicklist_throws() {
        Picklist pl = buildPendingPicklist();
        pl.setStatus("COMPLETED");
        when(picklistRepository.findByIdAndOrgIdAndIsDeletedFalse(pl.getId(), orgId))
                .thenReturn(Optional.of(pl));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancel(pl.getId()));
        assertEquals("PL_ALREADY_COMPLETED", ex.getErrorCode());
    }

    @Test
    void updatePickedQuantities_updatesLines() {
        Picklist pl = buildPendingPicklist();
        pl.setStatus("IN_PROGRESS");
        UUID lineId = pl.getLines().get(0).getId();

        when(picklistRepository.findByIdAndOrgIdAndIsDeletedFalse(pl.getId(), orgId))
                .thenReturn(Optional.of(pl));
        when(picklistRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(salesOrderRepository.findById(any())).thenReturn(Optional.empty());
        when(warehouseRepository.findById(any())).thenReturn(Optional.of(makeWarehouse(whId, "Main")));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList())).thenReturn(List.of());

        UpdatePicklistLineRequest req = new UpdatePicklistLineRequest(
                List.of(new UpdatePicklistLineRequest.PickedLineEntry(
                        lineId, new BigDecimal("5"), null, "Picked from shelf A")));

        PicklistResponse response = service.updatePickedQuantities(pl.getId(), req);

        assertEquals(1, response.pickedCount());
        assertEquals(new BigDecimal("5"), pl.getLines().get(0).getPickedQuantity());
    }

    private SalesOrder buildConfirmedSO() {
        SalesOrder so = SalesOrder.builder()
                .salesorderNumber("SO-2026-000001")
                .contactId(UUID.randomUUID())
                .orderDate(java.time.LocalDate.now())
                .build();
        so.setId(UUID.randomUUID());
        so.setOrgId(orgId);
        so.setStatus("CONFIRMED");

        SalesOrderLine line = SalesOrderLine.builder()
                .itemId(UUID.randomUUID())
                .lineNumber(1)
                .quantity(new BigDecimal("10"))
                .rate(new BigDecimal("100"))
                .amount(new BigDecimal("1000"))
                .build();
        line.setId(UUID.randomUUID());
        so.addLine(line);

        return so;
    }

    private Picklist buildPendingPicklist() {
        Picklist pl = Picklist.builder()
                .picklistNumber("PL-2026-000001")
                .salesOrderId(UUID.randomUUID())
                .warehouseId(whId)
                .build();
        pl.setId(UUID.randomUUID());
        pl.setOrgId(orgId);

        PicklistLine line = PicklistLine.builder()
                .salesOrderLineId(UUID.randomUUID())
                .itemId(UUID.randomUUID())
                .requiredQuantity(new BigDecimal("10"))
                .build();
        line.setId(UUID.randomUUID());
        pl.addLine(line);

        return pl;
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
