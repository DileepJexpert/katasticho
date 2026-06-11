package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.CostLot;
import com.katasticho.erp.inventory.entity.CostLotConsumption;
import com.katasticho.erp.inventory.entity.StockMovement;
import com.katasticho.erp.inventory.repository.CostLotConsumptionRepository;
import com.katasticho.erp.inventory.repository.CostLotRepository;
import com.katasticho.erp.inventory.repository.StockMovementRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * FIFO cost-lot ledger. Sits beside {@link InventoryService} (the single stock
 * gate) and is invoked only when an org's {@code inventory.valuation_method} is
 * {@code FIFO}. Weighted-average orgs never reach this service, so their
 * behaviour is byte-for-byte unchanged.
 *
 * <p>How it works:
 * <ul>
 *   <li><b>Receipt</b> (incoming movement) opens a {@link CostLot} carrying the
 *       receipt's unit cost and date.</li>
 *   <li><b>Issue</b> (outgoing movement) draws down open lots oldest-first; the
 *       blended FIFO cost it computes is baked into the movement's immutable
 *       {@code unit_cost}/{@code total_cost} <em>before</em> the row is built,
 *       and the per-lot draw is recorded in {@code cost_lot_consumption} so a
 *       reversal can put it back exactly.</li>
 *   <li><b>Valuation</b> = Σ(remaining_qty × unit_cost) over active lots.</li>
 * </ul>
 *
 * <p>If an org turns FIFO on with pre-existing stock that predates lot
 * tracking, the first issue lazily seeds an opening lot from the current
 * weighted-average balance so COGS and valuation stay coherent.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FifoCostingService {

    private final CostLotRepository costLotRepository;
    private final CostLotConsumptionRepository consumptionRepository;
    private final StockMovementRepository stockMovementRepository;
    private final OrgSettingsService orgSettingsService;

    /** Blended FIFO cost of an issue plus the per-lot draws that produced it. */
    public record FifoCost(BigDecimal unitCost, BigDecimal totalCost, List<Allocation> allocations) {}

    public record Allocation(UUID lotId, BigDecimal qty, BigDecimal unitCost) {}

    /** True when this org values inventory FIFO (vs weighted-average). */
    public boolean isFifo(UUID orgId) {
        return "FIFO".equalsIgnoreCase(
                orgSettingsService.get(orgId, "inventory.valuation_method", "WEIGHTED_AVERAGE"));
    }

    /**
     * Open a cost lot for an incoming movement. Same transaction as the
     * stock_movement insert.
     */
    @Transactional
    public void recordReceipt(StockMovement movement) {
        CostLot lot = CostLot.builder()
                .orgId(movement.getOrgId())
                .itemId(movement.getItemId())
                .warehouseId(movement.getWarehouseId())
                .sourceMovementId(movement.getId())
                .receivedDate(movement.getMovementDate())
                .originalQty(movement.getQuantity().abs())
                .remainingQty(movement.getQuantity().abs())
                .unitCost(movement.getUnitCost())
                .active(true)
                .createdBy(movement.getCreatedBy())
                .build();
        costLotRepository.save(lot);
    }

    /**
     * Draw down open lots oldest-first for an issue of {@code qtyAbs} units and
     * return the blended FIFO cost. Lots are decremented here; the matching
     * {@code cost_lot_consumption} rows are written by
     * {@link #recordConsumption(UUID, FifoCost)} once the movement id exists.
     *
     * @param fallbackUnitCost cost applied to any quantity not covered by lots
     *                         (negative stock / no history)
     * @param onHandBefore     current on-hand prior to this issue — used to seed
     *                         an opening lot when none exist yet
     * @param avgCost          weighted-average cost to value a seeded opening lot
     */
    @Transactional
    public FifoCost consume(UUID orgId, UUID itemId, UUID warehouseId, BigDecimal qtyAbs,
                            BigDecimal fallbackUnitCost, BigDecimal onHandBefore, BigDecimal avgCost,
                            java.time.LocalDate movementDate) {
        // findOpenLots takes a PESSIMISTIC_WRITE lock so two concurrent issues
        // of the same item×warehouse serialize instead of double-drawing lots.
        List<CostLot> lots = costLotRepository.findOpenLots(orgId, itemId, warehouseId);

        // Lazy opening lot: FIFO turned on over pre-existing stock with no lots.
        if (lots.isEmpty()) {
            CostLot opening = seedOpeningLot(orgId, itemId, warehouseId,
                    onHandBefore, avgCost, fallbackUnitCost, movementDate);
            if (opening != null) {
                lots = new ArrayList<>(List.of(opening));
            }
        }

        BigDecimal remaining = qtyAbs;
        BigDecimal totalCost = BigDecimal.ZERO;
        List<Allocation> allocations = new ArrayList<>();

        for (CostLot lot : lots) {
            if (remaining.signum() <= 0) break;
            BigDecimal take = remaining.min(lot.getRemainingQty());
            if (take.signum() <= 0) continue;
            totalCost = totalCost.add(take.multiply(lot.getUnitCost()));
            lot.setRemainingQty(lot.getRemainingQty().subtract(take).setScale(4, RoundingMode.HALF_UP));
            if (lot.getRemainingQty().signum() <= 0) lot.setActive(false);
            costLotRepository.save(lot);
            allocations.add(new Allocation(lot.getId(), take.setScale(4, RoundingMode.HALF_UP), lot.getUnitCost()));
            remaining = remaining.subtract(take);
        }

        // Anything lots couldn't cover (no history / negative stock) is costed
        // at the fallback so COGS is never zero; nothing to restore on reversal.
        if (remaining.signum() > 0) {
            BigDecimal fb = fallbackUnitCost != null ? fallbackUnitCost : BigDecimal.ZERO;
            totalCost = totalCost.add(remaining.multiply(fb));
        }

        totalCost = totalCost.setScale(2, RoundingMode.HALF_UP);
        BigDecimal unitCost = qtyAbs.signum() > 0
                ? totalCost.divide(qtyAbs, 4, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        return new FifoCost(unitCost, totalCost, allocations);
    }

    /**
     * Seed an opening lot from the pre-FIFO weighted-average balance when an
     * item×warehouse has stock but no lot history. Called from {@link #consume}
     * (first issue) and from the stock gate before the first FIFO receipt, so
     * a receipt arriving before any issue can't strand the pre-existing
     * on-hand outside the lot ledger forever. Returns null when there is
     * nothing to seed.
     */
    @Transactional
    public CostLot seedOpeningLot(UUID orgId, UUID itemId, UUID warehouseId,
                                  BigDecimal onHandBefore, BigDecimal avgCost,
                                  BigDecimal fallbackUnitCost,
                                  java.time.LocalDate movementDate) {
        if (onHandBefore == null || onHandBefore.signum() <= 0) {
            return null;
        }
        BigDecimal seedCost = (avgCost != null && avgCost.signum() > 0) ? avgCost
                : (fallbackUnitCost != null ? fallbackUnitCost : BigDecimal.ZERO);
        CostLot opening = CostLot.builder()
                .orgId(orgId).itemId(itemId).warehouseId(warehouseId)
                .sourceMovementId(null)
                .receivedDate(movementDate)
                .originalQty(onHandBefore)
                .remainingQty(onHandBefore)
                .unitCost(seedCost.setScale(4, RoundingMode.HALF_UP))
                .active(true)
                .createdBy(TenantContext.getCurrentUserId())
                .build();
        log.info("Seeded FIFO opening lot for item {} warehouse {}: {} @ {}",
                itemId, warehouseId, onHandBefore, seedCost);
        return costLotRepository.save(opening);
    }

    /**
     * Seed an opening lot before the first FIFO receipt if pre-FIFO stock
     * exists and no lots do. No-op otherwise.
     */
    @Transactional
    public void seedOpeningLotIfNeeded(UUID orgId, UUID itemId, UUID warehouseId,
                                       BigDecimal onHandBefore, BigDecimal avgCost,
                                       java.time.LocalDate movementDate) {
        if (onHandBefore == null || onHandBefore.signum() <= 0) {
            return;
        }
        if (costLotRepository.findOpenLots(orgId, itemId, warehouseId).isEmpty()) {
            seedOpeningLot(orgId, itemId, warehouseId, onHandBefore, avgCost, null, movementDate);
        }
    }

    /** Persist the per-lot draws now that the movement id is known. */
    @Transactional
    public void recordConsumption(UUID movementId, FifoCost plan) {
        UUID orgId = TenantContext.getCurrentOrgId();
        for (Allocation a : plan.allocations()) {
            consumptionRepository.save(CostLotConsumption.builder()
                    .orgId(orgId)
                    .lotId(a.lotId())
                    .movementId(movementId)
                    .qty(a.qty())
                    .unitCost(a.unitCost())
                    .build());
        }
    }

    /**
     * Undo a receipt's lot when that receipt is reversed. Pulls back the lot's
     * remaining quantity and closes it. If the lot was already partly consumed,
     * only the unconsumed remainder can be withdrawn (the rest already left as
     * COGS) — we log and close it.
     */
    @Transactional
    public void reverseReceipt(UUID sourceMovementId) {
        costLotRepository.findBySourceMovementId(sourceMovementId).ifPresent(lot -> {
            if (lot.getRemainingQty().compareTo(lot.getOriginalQty()) < 0) {
                log.warn("Reversing receipt {} whose lot was partly consumed ({} of {} left); closing lot",
                        sourceMovementId, lot.getRemainingQty(), lot.getOriginalQty());
            }
            lot.setRemainingQty(BigDecimal.ZERO);
            lot.setActive(false);
            costLotRepository.save(lot);
        });
    }

    /**
     * Restore the lots an issue consumed when that issue is reversed.
     *
     * <p>A lot whose backing receipt has itself been reversed is NOT restored:
     * the goods it represented no longer exist, so resurrecting it would
     * re-inject phantom quantity/value into the ledger (receipt → issue →
     * reverse receipt → reverse issue would otherwise leave a live lot over
     * zero physical stock).
     */
    @Transactional
    public void reverseConsumption(UUID movementId) {
        List<CostLotConsumption> rows = consumptionRepository.findByMovementId(movementId);
        for (CostLotConsumption row : rows) {
            costLotRepository.findById(row.getLotId()).ifPresent(lot -> {
                if (lot.getSourceMovementId() != null) {
                    boolean receiptReversed = stockMovementRepository
                            .findById(lot.getSourceMovementId())
                            .map(StockMovement::isReversed)
                            .orElse(false);
                    if (receiptReversed) {
                        log.warn("Not restoring {} units to lot {} — its source receipt {} was reversed",
                                row.getQty(), lot.getId(), lot.getSourceMovementId());
                        return;
                    }
                }
                lot.setRemainingQty(lot.getRemainingQty().add(row.getQty()).setScale(4, RoundingMode.HALF_UP));
                lot.setActive(true);
                costLotRepository.save(lot);
            });
        }
        consumptionRepository.deleteByMovementId(movementId);
    }

    /** All open lots for the org-wide FIFO valuation report. */
    @Transactional(readOnly = true)
    public List<CostLot> openLots(UUID orgId) {
        return costLotRepository.findAllOpenLots(orgId);
    }
}
