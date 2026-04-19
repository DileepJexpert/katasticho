package com.katasticho.erp.sales.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record SalesOrderLineRequest(
        /** Optional inventory item reference — free-text lines leave this null. */
        UUID itemId,

        String description,

        @NotNull(message = "Quantity is required")
        @DecimalMin(value = "0.001", message = "Quantity must be positive")
        BigDecimal quantity,

        @NotNull(message = "Rate is required")
        @DecimalMin(value = "0.00", message = "Rate must be >= 0")
        BigDecimal rate,

        String unit,
        BigDecimal discountPct,
        UUID taxGroupId,
        String hsnCode
) {
    public SalesOrderLineRequest {
        if (discountPct == null) discountPct = BigDecimal.ZERO;
    }
}
