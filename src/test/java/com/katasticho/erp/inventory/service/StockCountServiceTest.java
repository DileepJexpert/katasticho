package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.CreateStockCountRequest;
import com.katasticho.erp.inventory.dto.StockCountLineRequest;
import com.katasticho.erp.inventory.dto.StockCountResponse;
import com.katasticho.erp.inventory.dto.StockMovementRequest;
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
class StockCountServiceTest {

    @Mock private StockCountRepository stockCountRepository;
    @Mock private StockCountLineRepository lineRepository;
    @Mock private StockBalanceRepository stockBalanceRepository;
    @Mock private WarehouseRepository warehouseRepository;
    @Mock private ItemRepository itemRepository;
    @Mock private InventoryService inventoryService;

    private StockCountService service;
    private UUID orgId;
    private UUID userId;
    private UUID warehouseId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        service = new StockCountService(
                stockCountRepository, lineRepository,
                stockBalanceRepository, warehouseRepository,
                itemRepository, inventoryService);
        // post() now uses the pessimistic-locked finder — delegate it to the
        // plain finder so per-test stubs on the latter flow through.
        lenient().when(stockCountRepository.findByIdAndOrgIdForUpdate(any(), any()))
                .thenAnswer(inv -> stockCountRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(inv.getArgument(0), inv.getArgument(1)));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void create_happyPath_freezesSystemQuantityAndComputesVariance() {
        Warehouse wh = new Warehouse();
        wh.setId(warehouseId);
        wh.setName("Main");
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouseId, orgId))
                .thenReturn(Optional.of(wh));
        when(stockCountRepository.nextSequence(eq(orgId), anyString())).thenReturn(1);

        UUID itemId = UUID.randomUUID();
        Item item = Item.builder().build();
        item.setId(itemId);
        item.setOrgId(orgId);
        item.setName("Paracetamol");
        item.setSku("PARA-500");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item));

        StockBalance balance = StockBalance.builder().quantityOnHand(new BigDecimal("100")).build();
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.of(balance));

        when(stockCountRepository.save(any(StockCount.class))).thenAnswer(inv -> {
            StockCount sc = inv.getArgument(0);
            sc.setId(UUID.randomUUID());
            return sc;
        });
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList()))
                .thenReturn(List.of(item));

        CreateStockCountRequest request = new CreateStockCountRequest(
                warehouseId, LocalDate.now(), "Monthly count",
                List.of(new StockCountLineRequest(itemId, new BigDecimal("95"), "5 missing")));

        StockCountResponse response = service.create(request);

        assertEquals("DRAFT", response.status());
        assertEquals(1, response.lineCount());
        assertEquals(1, response.varianceCount());

        StockCountResponse.StockCountLineResponse line = response.lines().get(0);
        assertEquals(new BigDecimal("100"), line.expectedQuantity());
        assertEquals(new BigDecimal("95"), line.countedQuantity());
        assertEquals(new BigDecimal("-5"), line.variance());
    }

    @Test
    void post_recordsMovementsForVarianceLines() {
        StockCount sc = buildDraftStockCount();
        StockCountLine line = sc.getLines().get(0);
        line.setVariance(new BigDecimal("-5"));

        when(stockCountRepository.findByIdAndOrgIdAndIsDeletedFalse(sc.getId(), orgId))
                .thenReturn(Optional.of(sc));
        when(inventoryService.recordMovement(any())).thenReturn(new StockMovement());
        when(stockCountRepository.save(any(StockCount.class))).thenAnswer(inv -> inv.getArgument(0));

        Warehouse wh = new Warehouse();
        wh.setId(warehouseId);
        wh.setName("Main");
        when(warehouseRepository.findById(warehouseId)).thenReturn(Optional.of(wh));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList()))
                .thenReturn(List.of());

        StockCountResponse response = service.post(sc.getId());

        assertEquals("POSTED", response.status());
        assertNotNull(response.postedAt());

        ArgumentCaptor<StockMovementRequest> captor = ArgumentCaptor.forClass(StockMovementRequest.class);
        verify(inventoryService).recordMovement(captor.capture());

        StockMovementRequest req = captor.getValue();
        assertEquals(MovementType.STOCK_COUNT, req.movementType());
        assertEquals(new BigDecimal("-5"), req.quantity());
        assertEquals(ReferenceType.STOCK_COUNT, req.referenceType());
        assertEquals(sc.getId(), req.referenceId());
    }

    @Test
    void post_skipsZeroVarianceLines() {
        StockCount sc = buildDraftStockCount();
        StockCountLine line = sc.getLines().get(0);
        line.setVariance(BigDecimal.ZERO);

        when(stockCountRepository.findByIdAndOrgIdAndIsDeletedFalse(sc.getId(), orgId))
                .thenReturn(Optional.of(sc));
        when(stockCountRepository.save(any(StockCount.class))).thenAnswer(inv -> inv.getArgument(0));
        when(warehouseRepository.findById(warehouseId)).thenReturn(Optional.of(new Warehouse()));
        when(itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), anyList()))
                .thenReturn(List.of());

        service.post(sc.getId());

        verify(inventoryService, never()).recordMovement(any());
    }

    @Test
    void post_rejectsNonDraft() {
        StockCount sc = buildDraftStockCount();
        sc.setStatus("POSTED");

        when(stockCountRepository.findByIdAndOrgIdAndIsDeletedFalse(sc.getId(), orgId))
                .thenReturn(Optional.of(sc));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.post(sc.getId()));
        assertEquals("SC_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void create_rejectsDuplicateItem() {
        Warehouse wh = new Warehouse();
        wh.setId(warehouseId);
        wh.setName("Main");
        when(warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(warehouseId, orgId))
                .thenReturn(Optional.of(wh));
        when(stockCountRepository.nextSequence(eq(orgId), anyString())).thenReturn(1);

        UUID itemId = UUID.randomUUID();
        Item item = Item.builder().build();
        item.setId(itemId);
        item.setOrgId(orgId);
        item.setName("Test");
        item.setSku("TST");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item));
        when(stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId))
                .thenReturn(Optional.empty());

        CreateStockCountRequest request = new CreateStockCountRequest(
                warehouseId, LocalDate.now(), null,
                List.of(
                        new StockCountLineRequest(itemId, BigDecimal.TEN, null),
                        new StockCountLineRequest(itemId, BigDecimal.ONE, null)));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.create(request));
        assertEquals("SC_DUPLICATE_ITEM", ex.getErrorCode());
    }

    @Test
    void cancel_setsCancelledStatus() {
        StockCount sc = buildDraftStockCount();
        when(stockCountRepository.findByIdAndOrgIdAndIsDeletedFalse(sc.getId(), orgId))
                .thenReturn(Optional.of(sc));
        when(stockCountRepository.save(any(StockCount.class))).thenAnswer(inv -> inv.getArgument(0));

        service.cancel(sc.getId());

        assertEquals("CANCELLED", sc.getStatus());
    }

    private StockCount buildDraftStockCount() {
        StockCount sc = StockCount.builder()
                .warehouseId(warehouseId)
                .countNumber("SC-2026-000001")
                .countDate(LocalDate.now())
                .status("DRAFT")
                .build();
        sc.setId(UUID.randomUUID());
        sc.setOrgId(orgId);

        UUID itemId = UUID.randomUUID();
        StockCountLine line = StockCountLine.builder()
                .itemId(itemId)
                .expectedQuantity(new BigDecimal("100"))
                .countedQuantity(new BigDecimal("95"))
                .variance(new BigDecimal("-5"))
                .build();
        line.setId(UUID.randomUUID());
        sc.addLine(line);

        return sc;
    }
}
