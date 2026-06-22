package com.katasticho.erp.inventory.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link ProvisionalCostReconciler} — the GRN-time true-up.
 *
 * Math under test:
 *   journal = DR Suspense (provisional total)
 *           / CR Inventory (provisional total + variance)
 *           / DR/CR COGS (variance)
 * Variance = (actualCost − provisionalUnitCost) × |qty|, summed.
 */
@ExtendWith(MockitoExtension.class)
class ProvisionalCostReconcilerTest {

    @Mock private StockMovementRepository stockMovementRepo;
    @Mock private JournalService journalService;
    @Mock private DefaultAccountService defaultAccountService;

    private ProvisionalCostReconciler reconciler;
    private UUID orgId;
    private UUID itemId;
    private Clock fixedClock;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        itemId = UUID.randomUUID();
        fixedClock = Clock.fixed(Instant.parse("2026-06-22T10:00:00Z"), ZoneId.of("UTC"));
        reconciler = new ProvisionalCostReconciler(
                stockMovementRepo, journalService, defaultAccountService, fixedClock);
    }

    private void stubAccountCodes() {
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.STOCK_OUT_SUSPENSE)))
                .thenReturn("2042");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.COGS)))
                .thenReturn("5010");
        when(defaultAccountService.getCode(eq(orgId), eq(DefaultAccountPurpose.INVENTORY_ASSET)))
                .thenReturn("1200");
    }

    private StockMovement provisionalSale(BigDecimal unitCost, BigDecimal qty) {
        return StockMovement.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .itemId(itemId)
                .movementType(MovementType.SALE)
                .quantity(qty)
                .unitCost(unitCost)
                .totalCost(unitCost.multiply(qty.abs()))
                .costProvisional(true)
                .movementDate(LocalDate.of(2026, 6, 20))
                .build();
    }

    private JournalEntry stubJournalReturn(UUID id) {
        JournalEntry je = new JournalEntry();
        je.setId(id);
        when(journalService.postJournal(any(JournalPostRequest.class))).thenReturn(je);
        return je;
    }

    @Test
    void noPending_returnsZero_andPostsNoJournal() {
        when(stockMovementRepo.findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                orgId, itemId)).thenReturn(List.of());

        ProvisionalCostReconciler.ReconcileResult r =
                reconciler.reconcileForItem(orgId, itemId, new BigDecimal("20.00"), "GRN-1");

        assertThat(r.settled()).isZero();
        assertThat(r.journalEntryId()).isNull();
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void overEstimatedProvisional_creditsCogs() {
        // Provisional 22.50 × 2 = 45.00 booked. Actual cost 20.00.
        // Variance per movement = (20 − 22.50) × 2 = −5.00 (over-estimated).
        // Real inventory consumption = 45 + (−5) = 40.
        // Journal:  DR Suspense 45 / CR Inventory 40 / CR COGS 5
        StockMovement m = provisionalSale(new BigDecimal("22.50"), new BigDecimal("-2"));
        when(stockMovementRepo.findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                orgId, itemId)).thenReturn(List.of(m));
        stubAccountCodes();
        UUID jeId = UUID.randomUUID();
        stubJournalReturn(jeId);

        ProvisionalCostReconciler.ReconcileResult r =
                reconciler.reconcileForItem(orgId, itemId, new BigDecimal("20.00"), "GRN-1");

        assertThat(r.settled()).isOne();
        assertThat(r.totalProvisionalCogs()).isEqualByComparingTo("45.00");
        assertThat(r.totalVariance()).isEqualByComparingTo("-5.00");
        assertThat(r.journalEntryId()).isEqualTo(jeId);

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        List<JournalLineRequest> lines = captor.getValue().lines();
        assertThat(lines)
                .extracting(JournalLineRequest::accountCode,
                            JournalLineRequest::debit,
                            JournalLineRequest::credit)
                .containsExactly(
                        tuple("2042", new BigDecimal("45.00"), BigDecimal.ZERO),
                        tuple("1200", BigDecimal.ZERO, new BigDecimal("40.00")),
                        tuple("5010", BigDecimal.ZERO, new BigDecimal("5.00"))
                );
    }

    @Test
    void underEstimatedProvisional_debitsCogs() {
        // Provisional 22.50 × 2 = 45.00 booked. Actual cost 25.00.
        // Variance per movement = (25 − 22.50) × 2 = 5.00 (under-estimated).
        // Real inventory consumption = 45 + 5 = 50.
        // Journal:  DR Suspense 45 / CR Inventory 50 / DR COGS 5
        StockMovement m = provisionalSale(new BigDecimal("22.50"), new BigDecimal("-2"));
        when(stockMovementRepo.findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                orgId, itemId)).thenReturn(List.of(m));
        stubAccountCodes();
        stubJournalReturn(UUID.randomUUID());

        ProvisionalCostReconciler.ReconcileResult r =
                reconciler.reconcileForItem(orgId, itemId, new BigDecimal("25.00"), "GRN-1");

        assertThat(r.settled()).isOne();
        assertThat(r.totalProvisionalCogs()).isEqualByComparingTo("45.00");
        assertThat(r.totalVariance()).isEqualByComparingTo("5.00");

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        List<JournalLineRequest> lines = captor.getValue().lines();
        assertThat(lines)
                .extracting(JournalLineRequest::accountCode,
                            JournalLineRequest::debit,
                            JournalLineRequest::credit)
                .containsExactly(
                        tuple("2042", new BigDecimal("45.00"), BigDecimal.ZERO),
                        tuple("1200", BigDecimal.ZERO, new BigDecimal("50.00")),
                        tuple("5010", new BigDecimal("5.00"), BigDecimal.ZERO)
                );
    }

    @Test
    void aggregatesMultipleMovementsIntoOneJournal() {
        // Two provisional sales: 22.50 × 2 = 45.00, 30.00 × 1 = 30.00 → total 75.00 booked.
        // Actual cost 25.00.
        // Variance: (25 − 22.50) × 2 = 5.00 + (25 − 30) × 1 = −5.00 → net 0.00.
        // Real inventory consumption = 75 + 0 = 75.
        // Journal: DR Suspense 75 / CR Inventory 75 — no COGS line (variance is zero).
        StockMovement a = provisionalSale(new BigDecimal("22.50"), new BigDecimal("-2"));
        StockMovement b = provisionalSale(new BigDecimal("30.00"), new BigDecimal("-1"));
        when(stockMovementRepo.findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                orgId, itemId)).thenReturn(List.of(a, b));
        stubAccountCodes();
        stubJournalReturn(UUID.randomUUID());

        ProvisionalCostReconciler.ReconcileResult r =
                reconciler.reconcileForItem(orgId, itemId, new BigDecimal("25.00"), "GRN-2");

        assertThat(r.settled()).isEqualTo(2);
        assertThat(r.totalProvisionalCogs()).isEqualByComparingTo("75.00");
        assertThat(r.totalVariance()).isEqualByComparingTo("0.00");

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService, times(1)).postJournal(captor.capture());
        List<JournalLineRequest> lines = captor.getValue().lines();
        assertThat(lines).hasSize(2);
        assertThat(lines)
                .extracting(JournalLineRequest::accountCode,
                            JournalLineRequest::debit,
                            JournalLineRequest::credit)
                .containsExactly(
                        tuple("2042", new BigDecimal("75.00"), BigDecimal.ZERO),
                        tuple("1200", BigDecimal.ZERO, new BigDecimal("75.00"))
                );
    }

    @Test
    void stampsCostSettledAtOnAllMovements() {
        StockMovement m = provisionalSale(new BigDecimal("22.50"), new BigDecimal("-2"));
        assertThat(m.getCostSettledAt()).isNull();
        when(stockMovementRepo.findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                orgId, itemId)).thenReturn(List.of(m));
        stubAccountCodes();
        stubJournalReturn(UUID.randomUUID());

        reconciler.reconcileForItem(orgId, itemId, new BigDecimal("20.00"), "GRN-1");

        assertThat(m.getCostSettledAt())
                .isNotNull()
                .isEqualTo(Instant.parse("2026-06-22T10:00:00Z"));
        verify(stockMovementRepo).save(m);
    }

    @Test
    void nullActualCost_isNoOp() {
        ProvisionalCostReconciler.ReconcileResult r =
                reconciler.reconcileForItem(orgId, itemId, null, "GRN-NULL");

        assertThat(r.settled()).isZero();
        verify(stockMovementRepo, never())
                .findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                        any(), any());
        verify(journalService, never()).postJournal(any());
    }
}
