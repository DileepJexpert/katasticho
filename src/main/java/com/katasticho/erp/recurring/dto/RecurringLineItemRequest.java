package com.katasticho.erp.recurring.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record RecurringLineItemRequest(
        UUID itemId,

        @NotBlank(message = "Description is required")
        String description,

        String unit,

        String hsnCode,

        @NotNull(message = "Quantity is required")
        BigDecimal quantity,

        @NotNull(message = "Rate is required")
        BigDecimal rate,

        BigDecimal discountPct,

        BigDecimal taxRate,

        /** Optional override — defaults to system default revenue account. */
        String accountCode
) {
    public RecurringLineItemRequest {
        if (discountPct == null) discountPct = BigDecimal.ZERO;
        if (taxRate == null) taxRate = BigDecimal.ZERO;
    }
}
