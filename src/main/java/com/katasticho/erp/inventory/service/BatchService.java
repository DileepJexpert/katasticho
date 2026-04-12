package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.StockBatchBalance;
import com.katasticho.erp.inventory.repository.StockBatchBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Batch master lifecycle + per-batch balance updates.
 *
 * <p>Two responsibilities and nothing else:
 * <ol>
 *   <li>Upsert a {@link StockBatch} row from a
 *       {@code (org, item, batchNumber, expiry, mfg, unitCost)} tuple,
 *       used by GRN receive and bulk item import opening stock.</li>
 *   <li>Apply a signed delta to
 *       {@link StockBatchBalance} for a specific (batch, warehouse)
 *       pair. Called from
 *       {@code InventoryService.recordMovement()} in the same
 *       transaction as the immutable {@code stock_movement} insert.</li>
 * </ol>
 *
 * <p>This service deliberately does NOT implement the FEFO pick
 * algorithm itself — that lives in {@link InventoryService} because it
 * needs to iterate, post multiple movements, and coordinate with the
 * same single stock gate.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BatchService {

    private final StockBatchRepository batchRepository;
    private final StockBatchBalanceRepository batchBalanceRepository;

    /**
     * Upsert a batch row by natural key
     * {@code (org, item, batchNumber)}. If a row already exists we
     * leave it alone — attributes like expiry date and unit cost are
     * captured on the first receipt and never overwritten, so a typo
     * on a second receipt can't silently corrupt the first batch's
     * expiry date. Callers that really need to change a batch should
     * go through {@link #updateBatchAttributes}.
     *
     * @return the persisted batch row (new or pre-existing)
     */
    @Transactional
    public StockBatch upsertBatch(UUID itemId,
                                  String batchNumber,
                                  LocalDate expiryDate,
                                  LocalDate manufacturingDate,
                                  BigDecimal unitCost,
                                  UUID supplierId) {
        if (batchNumber == null || batchNumber.isBlank()) {
            throw new BusinessException("Batch number is required",
                    "BATCH_NUMBER_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        UUID orgId = TenantContext.getCurrentOrgId();
        String normalized = batchNumber.trim();

        return batchRepository
                .findByOrgIdAndItemIdAndBatchNumberAndIsDeletedFalse(orgId, itemId, normalized)
                .orElseGet(() -> {
                    StockBatch created = StockBatch.builder()
                            .itemId(itemId)
                            .batchNumber(normalized)
                            .expiryDate(expiryDate)
                            .manufacturingDate(manufacturingDate)
                            .unitCost(unitCost != null
                                    ? unitCost.setScale(4, RoundingMode.HALF_UP)
                                    : BigDecimal.ZERO)
                            .supplierId(supplierId)
                            .active(true)
                            .build();
                    StockBatch saved = batchRepository.save(created);
                    log.info("Created stock_batch {} item={} expiry={}",
                            saved.getBatchNumber(), itemId, expiryDate);
                    return saved;
                });
    }

    /**
     * Apply a signed quantity delta to a specific (batch, warehouse)
     * balance row, creating the row on the first touch. Negative
     * deltas are permitted but the post-delta balance is floor-clamped
     * at zero via a BusinessException if the caller would drive it
     * negative — FEFO pickers must have checked availability BEFORE
     * calling this.
     *
     * <p>Called from inside {@code InventoryService.recordMovement()}
     * which is already transactional, so this method is also
     * transactional and joins the caller's tx.
     */
    @Transactional
    public StockBatchBalance applyDelta(UUID batchId, UUID warehouseId, BigDecimal deltaQty) {
        UUID orgId = TenantContext.getCurrentOrgId();
        StockBatchBalance balance = batchBalanceRepository
                .findByOrgIdAndBatchIdAndWarehouseId(orgId, batchId, warehouseId)
                .orElseGet(() -> StockBatchBalance.builder()
                        .orgId(orgId)
                        .batchId(batchId)
                        .warehouseId(warehouseId)
                        .quantityOnHand(BigDecimal.ZERO)
                        .build());

        BigDecimal newQty = balance.getQuantityOnHand().add(deltaQty)
                .setScale(4, RoundingMode.HALF_UP);

        if (newQty.compareTo(BigDecimal.ZERO) < 0) {
            throw new BusinessException(
                    "Batch balance would go negative: " + newQty
                            + " for batch " + batchId + " in warehouse " + warehouseId,
                    "BATCH_NEGATIVE_BALANCE", HttpStatus.CONFLICT);
        }

        balance.setQuantityOnHand(newQty);
        balance.setLastMovementAt(Instant.now());
        return batchBalanceRepository.save(balance);
    }

    /**
     * FEFO-ordered list of batches that have stock available in the
     * given warehouse for the given item. Caller (the FEFO pick loop
     * in {@link InventoryService}) is responsible for iterating and
     * consuming against the balance rows.
     */
    @Transactional(readOnly = true)
    public List<StockBatch> findFefoBatches(UUID itemId, UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return batchRepository.findFefoBatches(orgId, itemId, warehouseId);
    }

    /**
     * Current on-hand quantity of one batch in one warehouse. Returns
     * zero if no balance row exists yet. Used by the FEFO picker to
     * size each deduction without loading every batch up front.
     */
    @Transactional(readOnly = true)
    public BigDecimal getBatchBalance(UUID batchId, UUID warehouseId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return batchBalanceRepository
                .findByOrgIdAndBatchIdAndWarehouseId(orgId, batchId, warehouseId)
                .map(StockBatchBalance::getQuantityOnHand)
                .orElse(BigDecimal.ZERO);
    }

    @Transactional(readOnly = true)
    public StockBatch getBatch(UUID batchId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return batchRepository.findByIdAndOrgIdAndIsDeletedFalse(batchId, orgId)
                .orElseThrow(() -> BusinessException.notFound("StockBatch", batchId));
    }

    /**
     * Limited update hook for operator corrections (typos in
     * expiry/mfg date). Unit cost is deliberately NOT editable here —
     * it's set by the first receipt and changes to it would retroactively
     * corrupt COGS on movements already posted.
     */
    @Transactional
    public StockBatch updateBatchAttributes(UUID batchId,
                                            LocalDate expiryDate,
                                            LocalDate manufacturingDate,
                                            String notes) {
        StockBatch batch = getBatch(batchId);
        if (expiryDate != null) batch.setExpiryDate(expiryDate);
        if (manufacturingDate != null) batch.setManufacturingDate(manufacturingDate);
        if (notes != null) batch.setNotes(notes);
        return batchRepository.save(batch);
    }
}
