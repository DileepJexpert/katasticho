package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Universal stock-movement request, accepted by InventoryService.recordMovement().
 *
 * Quantity is SIGNED:
 *   positive = stock in (PURCHASE, OPENING, ADJUSTMENT up, RETURN_IN, TRANSFER_IN)
 *   negative = stock out (SALE, ADJUSTMENT down, RETURN_OUT, TRANSFER_OUT)
 *
 * Reference fields are optional for ad-hoc adjustments and required for
 * document-driven movements (the service validates the combination).
 *
 * {@code batchId} is optional: it must be non-null when the item has
 * {@code track_batches=true}, and null otherwise. The service layer
 * enforces the invariant.
 *
 * {@code costProvisional} marks a SALE movement whose unit_cost was estimated
 * because the item had no known purchase price (V5 bill-freely true-up).
 * Defaults false so every legacy call site is byte-for-byte unchanged.
 */
public record StockMovementRequest(
        @NotNull UUID itemId,
        @NotNull UUID warehouseId,
        @NotNull MovementType movementType,
        @NotNull BigDecimal quantity,
        BigDecimal unitCost,
        @NotNull LocalDate movementDate,
        ReferenceType referenceType,
        UUID referenceId,
        String referenceNumber,
        String notes,
        UUID batchId,
        boolean costProvisional
) {
    /**
     * Backwards-compatible constructor for callers that don't track
     * batches. Defaults {@code batchId} to {@code null} and
     * {@code costProvisional} to {@code false}.
     */
    public StockMovementRequest(
            UUID itemId,
            UUID warehouseId,
            MovementType movementType,
            BigDecimal quantity,
            BigDecimal unitCost,
            LocalDate movementDate,
            ReferenceType referenceType,
            UUID referenceId,
            String referenceNumber,
            String notes) {
        this(itemId, warehouseId, movementType, quantity, unitCost, movementDate,
                referenceType, referenceId, referenceNumber, notes, null, false);
    }

    /**
     * Batch-aware constructor — every existing caller that already supplies
     * a batchId keeps working without edit; costProvisional defaults to false.
     */
    public StockMovementRequest(
            UUID itemId,
            UUID warehouseId,
            MovementType movementType,
            BigDecimal quantity,
            BigDecimal unitCost,
            LocalDate movementDate,
            ReferenceType referenceType,
            UUID referenceId,
            String referenceNumber,
            String notes,
            UUID batchId) {
        this(itemId, warehouseId, movementType, quantity, unitCost, movementDate,
                referenceType, referenceId, referenceNumber, notes, batchId, false);
    }
}
