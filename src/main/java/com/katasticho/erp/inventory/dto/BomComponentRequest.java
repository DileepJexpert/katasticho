package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Payload for {@code POST /api/v1/items/{parentId}/bom} — adds one
 * child line to a composite item's BOM. The parent itself is taken
 * from the path, so this record only carries {@code childItemId} and
 * the per-parent {@code quantity}.
 */
public record BomComponentRequest(
        @NotNull(message = "childItemId is required")
        UUID childItemId,

        /** Units of child required per single unit of parent. */
        @NotNull(message = "quantity is required")
        @DecimalMin(value = "0.0001", message = "quantity must be positive")
        BigDecimal quantity
) {
}
