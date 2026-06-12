package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Payload for {@code POST /api/v1/items/{parentId}/bom} — adds one
 * child line to a composite item's BOM. The parent itself is taken
 * from the path, so this record only carries {@code childItemId} and
 * the per-parent {@code quantity}.
 *
 * <p>{@code scrapPercent} is the expected process loss for this
 * component (issue path inflates by {@code 1 + scrapPercent/100}).
 * Optional; {@code null} is treated as 0.
 */
public record BomComponentRequest(
        @NotNull(message = "childItemId is required")
        UUID childItemId,

        /** Units of child required per single unit of parent. */
        @NotNull(message = "quantity is required")
        @DecimalMin(value = "0.0001", message = "quantity must be positive")
        BigDecimal quantity,

        @DecimalMin(value = "0", message = "scrapPercent cannot be negative")
        @DecimalMax(value = "99.99", message = "scrapPercent must be below 100")
        BigDecimal scrapPercent
) {
    /** Backwards-compatible two-arg form — scrapPercent defaults to 0. */
    public BomComponentRequest(UUID childItemId, BigDecimal quantity) {
        this(childItemId, quantity, null);
    }
}
