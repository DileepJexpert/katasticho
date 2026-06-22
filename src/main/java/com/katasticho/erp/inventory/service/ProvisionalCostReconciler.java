package com.katasticho.erp.inventory.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
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
 * Each provisional SALE movement was booked as
 *     DR COGS (provisional unitCost × qty)
 *     CR Stock-Out Suspense (same)
 * The Suspense liability is the placeholder — it says "we owe inventory $X
 * worth of consumption recognition, but we don't yet know the exact figure".
 *
 * When the GRN lands and {@code actualCost} is known, this reconciler walks
 * every unsettled provisional SALE for the item and posts ONE correction
 * journal:
 *     DR Stock-Out Suspense  totalProvisionalCogs        (close placeholder)
 *     CR Inventory           totalProvisionalCogs + variance  (real consumption)
 *     DR COGS                variance                    (if actual > provisional)
 *  or CR COGS                |variance|                  (if actual < provisional)
 * and stamps each affected movement with {@code costSettledAt = now} so it
 * never gets re-reconciled.
 *
 * Variance = (actualCost − provisionalUnitCost) × |qty|, summed across all
 * unsettled movements for the item.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProvisionalCostReconciler {

    private final StockMovementRepository stockMovementRepo;
    private final JournalService journalService;
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
     */
    @Transactional
    public ReconcileResult reconcileForItem(UUID orgId, UUID itemId,
                                            BigDecimal actualCost, String grnRef) {
        if (actualCost == null) {
            return new ReconcileResult(0, BigDecimal.ZERO, BigDecimal.ZERO, null);
        }

        List<StockMovement> pending = stockMovementRepo
                .findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                        orgId, itemId);
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
        // Close the suspense placeholder.
        lines.add(new JournalLineRequest(
                suspenseCode, totalProvisionalCogs, BigDecimal.ZERO,
                "Close provisional COGS suspense: " + grnRef, null, null));
        // Book real inventory consumption (the drop that was missing at sale time).
        lines.add(new JournalLineRequest(
                inventoryCode, BigDecimal.ZERO, realInventoryConsumption,
                "Inventory consumed (true-up): " + grnRef, null, null));
        // Variance to COGS.
        if (totalVariance.signum() > 0) {
            lines.add(new JournalLineRequest(
                    cogsCode, totalVariance, BigDecimal.ZERO,
                    "Cost variance (under-estimated): " + grnRef, null, null));
        } else if (totalVariance.signum() < 0) {
            lines.add(new JournalLineRequest(
                    cogsCode, BigDecimal.ZERO, totalVariance.negate(),
                    "Cost variance refund (over-estimated): " + grnRef, null, null));
        }

        JournalEntry je = journalService.postJournal(new JournalPostRequest(
                LocalDate.now(clock),
                "Provisional COGS true-up: " + grnRef,
                "GRN_RECONCILE",
                null,
                lines,
                true));

        Instant now = Instant.now(clock);
        for (StockMovement m : pending) {
            m.setCostSettledAt(now);
            stockMovementRepo.save(m);
        }

        log.info("Reconciled {} provisional SALE movement(s) for item {} (org {}): "
                        + "provisionalCogs={}, variance={}, je={}",
                pending.size(), itemId, orgId, totalProvisionalCogs, totalVariance, je.getId());

        return new ReconcileResult(pending.size(), totalProvisionalCogs, totalVariance, je.getId());
    }

    // Used by tests + observability — list everything still pending for an org.
    @Transactional(readOnly = true)
    public Map<UUID, Integer> pendingCountsByItem(UUID orgId, List<UUID> itemIds) {
        Map<UUID, Integer> out = new HashMap<>();
        for (UUID itemId : itemIds) {
            int n = stockMovementRepo
                    .findByOrgIdAndItemIdAndCostProvisionalTrueAndCostSettledAtIsNullOrderByMovementDateAscCreatedAtAsc(
                            orgId, itemId)
                    .size();
            if (n > 0) out.put(itemId, n);
        }
        return out;
    }
}
