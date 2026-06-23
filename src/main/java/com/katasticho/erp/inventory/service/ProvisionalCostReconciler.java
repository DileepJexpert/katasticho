package com.katasticho.erp.inventory.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Closes the COGS books on a "bill-freely" item once a GRN has revealed the
 * true purchase cost.
 *
 * <p>Each provisional SALE movement was booked as
 * <pre>
 *     DR COGS (provisional unitCost × qty)
 *     CR Stock-Out Suspense (same)
 * </pre>
 * The Suspense liability is the placeholder — "we owe inventory ~$X of
 * consumption recognition, exact figure pending".
 *
 * <p>When the GRN lands and {@code actualCost} is known, this reconciler walks
 * every unsettled provisional SALE for the item and posts ONE correction
 * journal:
 * <pre>
 *     DR Stock-Out Suspense  totalProvisionalCogs
 *     CR Inventory           totalProvisionalCogs + variance
 *     DR COGS                variance  (if actual > provisional)
 *  or CR COGS                |variance| (if actual < provisional)
 * </pre>
 * and stamps each affected movement with {@code costSettledAt = now} +
 * {@code costSettledByGrnId = grnId} so it never gets re-reconciled — until
 * the GRN is cancelled (see {@link #revertSettlementForGrn}), at which point
 * the stamps clear and the correction journal is reversed.
 *
 * <p>Runs in {@code REQUIRES_NEW} so a reconciliation failure (e.g. missing
 * CoA account) cannot mark the outer GRN transaction rollback-only — a Spring
 * gotcha that would otherwise blow up the entire receipt with
 * {@code UnexpectedRollbackException} even though the caller tries to swallow.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProvisionalCostReconciler {

    private static final String JOURNAL_SOURCE = "GRN_RECONCILE";

    private final StockMovementRepository stockMovementRepo;
    private final JournalService journalService;
    private final JournalEntryRepository journalEntryRepository;
    private final DefaultAccountService defaultAccountService;
    private final Clock clock;

    public record ReconcileResult(
            int settled,
            BigDecimal totalProvisionalCogs,
            BigDecimal totalVariance,
            UUID journalEntryId) {}

    /**
     * Idempotent: re-running with the same (orgId, itemId, actualCost) after
     * everything is settled returns {@code settled=0} with no journal posted.
     *
     * @param actualCost the true per-unit cost from the GRN line
     * @param grnRef     human label for the correction journal description
     * @param grnId      reference to the GRN that's settling — stamped on each
     *                   affected movement so a future GRN cancel can find and
     *                   unwind the settlement
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public ReconcileResult reconcileForItem(UUID orgId, UUID itemId,
                                            BigDecimal actualCost, String grnRef,
                                            UUID grnId) {
        if (actualCost == null) {
            return new ReconcileResult(0, BigDecimal.ZERO, BigDecimal.ZERO, null);
        }

        List<StockMovement> pending = stockMovementRepo.findUnsettledProvisional(orgId, itemId);
        if (pending.isEmpty()) {
            return new ReconcileResult(0, BigDecimal.ZERO, BigDecimal.ZERO, null);
        }

        // Compute net variance + total provisional COGS booked.
        BigDecimal totalVariance = BigDecimal.ZERO;
        BigDecimal totalProvisionalCogs = BigDecimal.ZERO;
        for (StockMovement m : pending) {
            BigDecimal qty = m.getQuantity().abs();
            BigDecimal variance = actualCost.subtract(m.getUnitCost())
                    .multiply(qty)
                    .setScale(2, RoundingMode.HALF_UP);
            totalVariance = totalVariance.add(variance);
            totalProvisionalCogs = totalProvisionalCogs.add(
                    m.getUnitCost().multiply(qty).setScale(2, RoundingMode.HALF_UP));
        }

        String suspenseCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.STOCK_OUT_SUSPENSE);
        String cogsCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.COGS);
        String inventoryCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.INVENTORY_ASSET);

        BigDecimal realInventoryConsumption = totalProvisionalCogs.add(totalVariance);

        List<JournalLineRequest> lines = new ArrayList<>();
        if (totalProvisionalCogs.signum() > 0) {
            lines.add(new JournalLineRequest(
                    suspenseCode, totalProvisionalCogs, BigDecimal.ZERO,
                    "Close provisional COGS suspense: " + grnRef, null, null));
        }
        if (realInventoryConsumption.signum() > 0) {
            lines.add(new JournalLineRequest(
                    inventoryCode, BigDecimal.ZERO, realInventoryConsumption,
                    "Inventory consumed (true-up): " + grnRef, null, null));
        }
        if (totalVariance.signum() > 0) {
            lines.add(new JournalLineRequest(
                    cogsCode, totalVariance, BigDecimal.ZERO,
                    "Cost variance (under-estimated): " + grnRef, null, null));
        } else if (totalVariance.signum() < 0) {
            lines.add(new JournalLineRequest(
                    cogsCode, BigDecimal.ZERO, totalVariance.negate(),
                    "Cost variance refund (over-estimated): " + grnRef, null, null));
        }

        JournalEntry je = null;
        if (!lines.isEmpty()) {
            je = journalService.postJournal(new JournalPostRequest(
                    LocalDate.now(clock),
                    "Provisional COGS true-up: " + grnRef,
                    JOURNAL_SOURCE,
                    grnId,
                    lines,
                    true));
        }

        Instant now = Instant.now(clock);
        for (StockMovement m : pending) {
            m.setCostSettledAt(now);
            m.setCostSettledByGrnId(grnId);
            stockMovementRepo.save(m);
        }

        log.info("Reconciled {} provisional SALE movement(s) for item {} (org {}): "
                        + "provisionalCogs={}, variance={}, je={}",
                pending.size(), itemId, orgId, totalProvisionalCogs, totalVariance,
                je != null ? je.getId() : null);

        return new ReconcileResult(pending.size(), totalProvisionalCogs, totalVariance,
                je != null ? je.getId() : null);
    }

    /**
     * Unwind every settlement this GRN caused: reverse the correction
     * journal(s) and clear {@code costSettledAt} / {@code costSettledByGrnId}
     * on each affected SALE movement so the NEXT GRN can re-reconcile with
     * the new actual cost. Idempotent — re-running on a fully-reverted GRN is
     * a no-op.
     *
     * <p>Runs in {@code REQUIRES_NEW} for the same reason as {@code reconcileForItem}.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void revertSettlementForGrn(UUID grnId) {
        if (grnId == null) return;

        // Reverse the correction journal(s) — there's one per item per call
        // to reconcileForItem; the GRN-receive loop calls per item, so multiple
        // JEs against the same GRN reference are normal. GRN id is globally
        // unique so the (sourceModule, sourceId) tuple is enough.
        List<JournalEntry> jes = journalEntryRepository
                .findBySourceModuleAndSourceIdAndStatus(JOURNAL_SOURCE, grnId, "POSTED");
        for (JournalEntry je : jes) {
            try {
                journalService.reverseEntry(je.getId());
            } catch (Exception e) {
                log.warn("Failed to reverse reconciliation JE {} for GRN {}: {}",
                        je.getId(), grnId, e.getMessage());
            }
        }

        // Clear stamps so the next GRN reconciles these movements fresh.
        List<StockMovement> settled = stockMovementRepo
                .findByCostSettledByGrnIdAndReversedFalse(grnId);
        for (StockMovement m : settled) {
            m.setCostSettledAt(null);
            m.setCostSettledByGrnId(null);
            stockMovementRepo.save(m);
        }
        if (!settled.isEmpty()) {
            log.info("Reverted {} provisional settlement(s) for cancelled GRN {}",
                    settled.size(), grnId);
        }
    }

    // Used by tests + observability — list everything still pending for an org.
    @Transactional(readOnly = true)
    public Map<UUID, Integer> pendingCountsByItem(UUID orgId, List<UUID> itemIds) {
        Map<UUID, Integer> out = new HashMap<>();
        for (UUID itemId : itemIds) {
            int n = stockMovementRepo.findUnsettledProvisional(orgId, itemId).size();
            if (n > 0) out.put(itemId, n);
        }
        return out;
    }
}
