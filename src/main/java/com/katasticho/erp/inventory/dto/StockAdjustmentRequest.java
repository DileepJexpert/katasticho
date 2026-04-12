package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Manual stock adjustment (loss, damage, found stock, recount).
 *
 * Quantity is SIGNED — positive adds stock, negative removes stock.
 * The service translates this into a {@code MovementType.ADJUSTMENT}
 * stock_movement row.
 *
 * {@code warehouseId} and {@code adjustmentDate} are optional — when omitted
 * the service uses the org's default warehouse and today's date.
 */
public record StockAdjustmentRequest(
        @NotNull UUID itemId,
        UUID warehouseId,
        @NotNull BigDecimal quantity,
        BigDecimal unitCost,
        LocalDate adjustmentDate,
        String reason
) {}
