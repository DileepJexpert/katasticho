package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.CostLot;
import com.katasticho.erp.inventory.entity.CostLotConsumption;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.CostLotConsumptionRepository;
import com.katasticho.erp.inventory.repository.CostLotRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link FifoCostingService} — the cost-lot engine behind FIFO
 * valuation. Covers: setting detection, oldest-first draw-down with a blended
 * cost, lazy opening-lot seeding, fallback when lots run dry, receipt lot
 * creation, and reversal restore.
 */
@ExtendWith(MockitoExtension.class)
class FifoCostingServiceTest {

    @Mock private CostLotRepository costLotRepository;
    @Mock private CostLotConsumptionRepository consumptionRepository;
    @Mock private StockMovementRepository stockMovementRepository;
    @Mock private OrgSettingsService orgSettingsService;

    private FifoCostingService service;
    private UUID orgId;
    private UUID itemId;
    private UUID warehouseId;

    @BeforeEach
    void setUp() {
        service = new FifoCostingService(costLotRepository, consumptionRepository,
                stockMovementRepository, orgSettingsService);
        orgId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        lenient().when(costLotRepository.save(any(CostLot.class))).thenAnswer(inv -> {
            CostLot l = inv.getArgument(0);
            if (l.getId() == null) l.setId(UUID.randomUUID());
            return l;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void isFifo_readsSetting() {
        when(orgSettingsService.get(eq(orgId), eq("inventory.valuation_method"), anyString())).thenReturn("FIFO");
        assertTrue(service.isFifo(orgId));

        when(orgSettingsService.get(eq(orgId), eq("inventory.valuation_method"), anyString())).thenReturn("WEIGHTED_AVERAGE");
        assertFalse(service.isFifo(orgId));
    }

    @Test
    void consume_drawsLotsOldestFirst_blendsCost() {
        CostLot older = lot(new BigDecimal("10"), new BigDecimal("8"), LocalDate.of(2026, 1, 1));
        CostLot newer = lot(new BigDecimal("10"), new BigDecimal("12"), LocalDate.of(2026, 2, 1));
        when(costLotRepository.findOpenLots(orgId, itemId, warehouseId)).thenReturn(List.of(older, newer));

        FifoCostingService.FifoCost result = service.consume(orgId, itemId, warehouseId,
                new BigDecimal("15"), new BigDecimal("99"), new BigDecimal("20"), new BigDecimal("10"),
                LocalDate.of(2026, 3, 1));

        // 10 @ 8 + 5 @ 12 = 140, over 15 units = 9.3333/unit
        assertEquals(0, new BigDecimal("140.00").compareTo(result.totalCost()));
        assertEquals(0, new BigDecimal("9.3333").compareTo(result.unitCost()));
        assertEquals(2, result.allocations().size());
        // Older lot fully drained and deactivated; newer lot has 5 left.
        assertEquals(0, BigDecimal.ZERO.compareTo(older.getRemainingQty()));
        assertFalse(older.isActive());
        assertEquals(0, new BigDecimal("5").compareTo(newer.getRemainingQty()));
        assertTrue(newer.isActive());
    }

    @Test
    void consume_noLots_seedsOpeningLotFromBalance() {
        when(costLotRepository.findOpenLots(orgId, itemId, warehouseId)).thenReturn(List.of());

        FifoCostingService.FifoCost result = service.consume(orgId, itemId, warehouseId,
                new BigDecimal("8"), new BigDecimal("99"), new BigDecimal("20"), new BigDecimal("5"),
                LocalDate.of(2026, 3, 1));

        // Opening lot seeded at avg cost 5; 8 units cost 40.
        assertEquals(0, new BigDecimal("40.00").compareTo(result.totalCost()));
        assertEquals(0, new BigDecimal("5.0000").compareTo(result.unitCost()));
        ArgumentCaptor<CostLot> captor = ArgumentCaptor.forClass(CostLot.class);
        verify(costLotRepository, atLeastOnce()).save(captor.capture());
        CostLot seeded = captor.getAllValues().get(0);
        assertNull(seeded.getSourceMovementId(), "seeded opening lot has no source movement");
        assertEquals(0, new BigDecimal("20").compareTo(seeded.getOriginalQty()));
    }

    @Test
    void consume_lotsInsufficient_fallbackCostsRemainder() {
        CostLot only = lot(new BigDecimal("5"), new BigDecimal("10"), LocalDate.of(2026, 1, 1));
        when(costLotRepository.findOpenLots(orgId, itemId, warehouseId)).thenReturn(List.of(only));

        // onHandBefore matches the lot, so no opening-lot seed; lots cover 5 of 8.
        FifoCostingService.FifoCost result = service.consume(orgId, itemId, warehouseId,
                new BigDecimal("8"), new BigDecimal("7"), new BigDecimal("5"), new BigDecimal("10"),
                LocalDate.of(2026, 3, 1));

        // 5 @ 10 + 3 @ 7 (fallback) = 71
        assertEquals(0, new BigDecimal("71.00").compareTo(result.totalCost()));
        assertEquals(1, result.allocations().size(), "only the real lot draw is recorded");
    }

    @Test
    void recordReceipt_opensLotFromMovement() {
        StockMovement m = StockMovement.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .movementType(MovementType.PURCHASE)
                .movementDate(LocalDate.of(2026, 3, 1))
                .quantity(new BigDecimal("25"))
                .unitCost(new BigDecimal("9.5"))
                .build();
        m.setId(UUID.randomUUID());

        service.recordReceipt(m);

        ArgumentCaptor<CostLot> captor = ArgumentCaptor.forClass(CostLot.class);
        verify(costLotRepository).save(captor.capture());
        CostLot lot = captor.getValue();
        assertEquals(m.getId(), lot.getSourceMovementId());
        assertEquals(0, new BigDecimal("25").compareTo(lot.getOriginalQty()));
        assertEquals(0, new BigDecimal("25").compareTo(lot.getRemainingQty()));
        assertEquals(0, new BigDecimal("9.5").compareTo(lot.getUnitCost()));
    }

    @Test
    void reverseConsumption_restoresLotsAndDeletesRows() {
        UUID movementId = UUID.randomUUID();
        UUID lotId = UUID.randomUUID();
        CostLotConsumption row = CostLotConsumption.builder()
                .orgId(orgId).lotId(lotId).movementId(movementId)
                .qty(new BigDecimal("5")).unitCost(new BigDecimal("8")).build();
        when(consumptionRepository.findByMovementId(movementId)).thenReturn(List.of(row));
        CostLot lot = lot(new BigDecimal("0"), new BigDecimal("8"), LocalDate.of(2026, 1, 1));
        lot.setActive(false);
        lot.setId(lotId);
        when(costLotRepository.findById(lotId)).thenReturn(Optional.of(lot));

        service.reverseConsumption(movementId);

        assertEquals(0, new BigDecimal("5").compareTo(lot.getRemainingQty()));
        assertTrue(lot.isActive());
        verify(consumptionRepository).deleteByMovementId(movementId);
    }

    @Test
    void reverseReceipt_zeroesAndClosesLot() {
        UUID sourceMovementId = UUID.randomUUID();
        CostLot lot = lot(new BigDecimal("6"), new BigDecimal("8"), LocalDate.of(2026, 1, 1));
        lot.setOriginalQty(new BigDecimal("10")); // partly consumed already
        lot.setSourceMovementId(sourceMovementId);
        when(costLotRepository.findBySourceMovementId(sourceMovementId)).thenReturn(Optional.of(lot));

        service.reverseReceipt(sourceMovementId);

        assertEquals(0, BigDecimal.ZERO.compareTo(lot.getRemainingQty()));
        assertFalse(lot.isActive());
        verify(costLotRepository).save(lot);
    }

    @Test
    void reverseConsumption_doesNotResurrectLotWhoseReceiptWasReversed() {
        // receipt → issue → reverse receipt → reverse issue: the lot was closed
        // by the receipt reversal; restoring the issue's draw would re-inject
        // phantom quantity over zero physical stock.
        UUID movementId = UUID.randomUUID();
        UUID lotId = UUID.randomUUID();
        UUID sourceMovementId = UUID.randomUUID();
        CostLotConsumption row = CostLotConsumption.builder()
                .orgId(orgId).lotId(lotId).movementId(movementId)
                .qty(new BigDecimal("4")).unitCost(new BigDecimal("8")).build();
        when(consumptionRepository.findByMovementId(movementId)).thenReturn(List.of(row));

        CostLot lot = lot(new BigDecimal("0"), new BigDecimal("8"), LocalDate.of(2026, 1, 1));
        lot.setActive(false);
        lot.setId(lotId);
        lot.setSourceMovementId(sourceMovementId);
        when(costLotRepository.findById(lotId)).thenReturn(Optional.of(lot));

        StockMovement reversedReceipt = StockMovement.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .movementType(MovementType.PURCHASE)
                .quantity(new BigDecimal("10"))
                .build();
        reversedReceipt.setId(sourceMovementId);
        reversedReceipt.setReversed(true);
        when(stockMovementRepository.findById(sourceMovementId)).thenReturn(Optional.of(reversedReceipt));

        service.reverseConsumption(movementId);

        assertEquals(0, BigDecimal.ZERO.compareTo(lot.getRemainingQty()), "no phantom restore");
        assertFalse(lot.isActive());
        verify(costLotRepository, never()).save(lot);
        verify(consumptionRepository).deleteByMovementId(movementId);
    }

    @Test
    void seedOpeningLotIfNeeded_seedsOnlyWhenNoLotsAndStockExists() {
        // No lots + on-hand 30 → seeds an opening lot at the average cost.
        when(costLotRepository.findOpenLots(orgId, itemId, warehouseId)).thenReturn(List.of());

        service.seedOpeningLotIfNeeded(orgId, itemId, warehouseId,
                new BigDecimal("30"), new BigDecimal("6"), LocalDate.of(2026, 3, 1));

        ArgumentCaptor<CostLot> captor = ArgumentCaptor.forClass(CostLot.class);
        verify(costLotRepository).save(captor.capture());
        CostLot seeded = captor.getValue();
        assertNull(seeded.getSourceMovementId());
        assertEquals(0, new BigDecimal("30").compareTo(seeded.getRemainingQty()));
        assertEquals(0, new BigDecimal("6.0000").compareTo(seeded.getUnitCost()));

        // Lots already exist → no second opening lot.
        reset(costLotRepository);
        when(costLotRepository.findOpenLots(orgId, itemId, warehouseId))
                .thenReturn(List.of(lot(new BigDecimal("30"), new BigDecimal("6"), LocalDate.of(2026, 3, 1))));
        service.seedOpeningLotIfNeeded(orgId, itemId, warehouseId,
                new BigDecimal("30"), new BigDecimal("6"), LocalDate.of(2026, 3, 2));
        verify(costLotRepository, never()).save(any(CostLot.class));
    }

    private CostLot lot(BigDecimal remaining, BigDecimal cost, LocalDate received) {
        CostLot l = CostLot.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .receivedDate(received)
                .originalQty(remaining)
                .remainingQty(remaining)
                .unitCost(cost)
                .active(true)
                .build();
        l.setId(UUID.randomUUID());
        return l;
    }
}
