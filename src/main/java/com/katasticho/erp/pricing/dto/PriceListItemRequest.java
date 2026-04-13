package com.katasticho.erp.pricing.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record PriceListItemRequest(
        @NotNull(message = "itemId is required")
        UUID itemId,

        /** Defaults to 1 if null — every tier must be reachable. */
        @DecimalMin(value = "0.0001", message = "minQuantity must be positive")
        BigDecimal minQuantity,

        @NotNull(message = "price is required")
        @DecimalMin(value = "0.00", message = "price must be >= 0")
        BigDecimal price
) {
    public PriceListItemRequest {
        if (minQuantity == null) minQuantity = BigDecimal.ONE;
    }
}
