package com.katasticho.erp.estimate.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record EstimateLineRequest(
        /** Optional inventory item reference — free-text lines leave this null. */
        UUID itemId,

        @NotBlank(message = "Description is required")
        String description,

        String unit,
        String hsnCode,

        @NotNull(message = "Quantity is required")
        @DecimalMin(value = "0.001", message = "Quantity must be positive")
        BigDecimal quantity,

        @NotNull(message = "Rate is required")
        @DecimalMin(value = "0.00", message = "Rate must be >= 0")
        BigDecimal rate,

        BigDecimal discountPct,
        BigDecimal taxRate
) {
    public EstimateLineRequest {
        if (discountPct == null) discountPct = BigDecimal.ZERO;
        if (taxRate == null) taxRate = BigDecimal.ZERO;
    }
}
