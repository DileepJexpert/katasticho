package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Request payload for the expiry-return endpoint.
 * Each {@link ReturnLine} identifies a batch (or item) and the quantity
 * to deduct from the warehouse as a RETURN_OUT movement.
 */
public record ExpiryReturnRequest(
        UUID warehouseId,
        @NotNull LocalDate returnDate,
        String reason,
        @NotEmpty List<ReturnLine> lines
) {
    public record ReturnLine(
            @NotNull UUID itemId,
            @NotNull BigDecimal quantity,
            UUID batchId
    ) {}
}
