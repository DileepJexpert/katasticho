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
        String notes
) {}
