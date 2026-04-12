package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.repository.StockBatchBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for the batch lifecycle service. Covers the two contracts
 * that every downstream v2 feature depends on:
 *
 *   1. upsertBatch is idempotent on (org, item, batchNumber) — the
 *      same GRN coming in twice must NOT create a duplicate batch row.
 *   2. applyDelta refuses to drive a balance negative so a buggy FEFO
 *      picker can't over-consume a batch.
 */
@ExtendWith(MockitoExtension.class)
class BatchServiceTest {

    @Mock private StockBatchRepository batchRepository;
    @Mock private StockBatchBalanceRepository balanceRepository;

    private BatchService batchService;
    private UUID orgId;
    private UUID userId;
    private UUID itemId;
    private UUID warehouseId;

    @BeforeEach
    void setUp() {
        batchService = new BatchService(batchRepository, balanceRepository);
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        warehouseId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void upsertBatch_createsNewRowWhenNoneExists() {
        when(batchRepository.findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse(
                orgId, itemId, "LOT-A"))
                .thenReturn(Optional.empty());
        when(batchRepository.save(any(StockBatch.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        StockBatch result = batchService.upsertBatch(
                itemId, "LOT-A",
                LocalDate.of(2027, 1, 1),
                LocalDate.of(2026, 1, 1),
                new BigDecimal("12.50"),
                null);

        assertEquals("LOT-A", result.getBatchNumber());
        assertEquals(LocalDate.of(2027, 1, 1), result.getExpiryDate());
        assertEquals(0, new BigDecimal("12.5000").compareTo(result.getUnitCost()));

        ArgumentCaptor<StockBatch> captor = ArgumentCaptor.forClass(StockBatch.class);
        verify(batchRepository).save(captor.capture());
        assertEquals(itemId, captor.getValue().getItemId());
    }

    @Test
    void upsertBatch_returnsExistingRowWithoutMutating() {
        StockBatch existing = StockBatch.builder()
                .itemId(itemId)
                .batchNumber("LOT-A")
                .expiryDate(LocalDate.of(2027, 1, 1))
                .unitCost(new BigDecimal("10.00"))
                .active(true)
                .build();
        existing.setId(UUID.randomUUID());

        when(batchRepository.findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse(
                orgId, itemId, "LOT-A"))
                .thenReturn(Optional.of(existing));

        StockBatch result = batchService.upsertBatch(
                itemId, "LOT-A",
                LocalDate.of(2030, 1, 1),  // would-be typo overrides
                null,
                new BigDecimal("99.99"),
                null);

        // Original expiry + cost must be preserved — first receipt wins.
        assertSame(existing, result);
        assertEquals(LocalDate.of(2027, 1, 1), result.getExpiryDate());
        assertEquals(0, new BigDecimal("10.00").compareTo(result.getUnitCost()));
        verify(batchRepository, never()).save(any());
    }

    @Test
    void upsertBatch_blankBatchNumberThrows() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> batchService.upsertBatch(itemId, "  ", null, null, null, null));
        assertEquals("BATCH_NUMBER_REQUIRED", ex.getErrorCode());
        verifyNoInteractions(batchRepository);
    }

    @Test
    void applyDelta_incrementsExistingBalance() {
        UUID batchId = UUID.randomUUID();
        StockBatchBalance existing = StockBatchBalance.builder()
                .orgId(orgId)
                .batchId(batchId)
                .warehouseId(warehouseId)
                .quantityOnHand(new BigDecimal("10"))
                .build();

        when(balanceRepository.findByOrgIdAndBatchIdAndWarehouseId(orgId, batchId, warehouseId))
                .thenReturn(Optional.of(existing));
        when(balanceRepository.save(any(StockBatchBalance.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        StockBatchBalance result = batchService.applyDelta(
                batchId, warehouseId, new BigDecimal("5"));

        assertEquals(0, new BigDecimal("15.0000").compareTo(result.getQuantityOnHand()));
    }

    @Test
    void applyDelta_refusesNegativeBalance() {
        UUID batchId = UUID.randomUUID();
        StockBatchBalance existing = StockBatchBalance.builder()
                .orgId(orgId)
                .batchId(batchId)
                .warehouseId(warehouseId)
                .quantityOnHand(new BigDecimal("3"))
                .build();

        when(balanceRepository.findByOrgIdAndBatchIdAndWarehouseId(orgId, batchId, warehouseId))
                .thenReturn(Optional.of(existing));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> batchService.applyDelta(batchId, warehouseId, new BigDecimal("-5")));
        assertEquals("BATCH_NEGATIVE_BALANCE", ex.getErrorCode());
        verify(balanceRepository, never()).save(any());
    }

    @Test
    void applyDelta_createsBalanceOnFirstTouch() {
        UUID batchId = UUID.randomUUID();
        when(balanceRepository.findByOrgIdAndBatchIdAndWarehouseId(orgId, batchId, warehouseId))
                .thenReturn(Optional.empty());
        when(balanceRepository.save(any(StockBatchBalance.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        StockBatchBalance result = batchService.applyDelta(
                batchId, warehouseId, new BigDecimal("100"));

        assertEquals(0, new BigDecimal("100.0000").compareTo(result.getQuantityOnHand()));
        assertEquals(batchId, result.getBatchId());
        assertEquals(warehouseId, result.getWarehouseId());
    }
}
