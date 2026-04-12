package com.katasticho.erp.ar.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record InvoiceLineRequest(
        @NotBlank(message = "Description is required")
        String description,

        String hsnCode,

        @NotNull(message = "Quantity is required")
        @DecimalMin(value = "0.01", message = "Quantity must be positive")
        BigDecimal quantity,

        @NotNull(message = "Unit price is required")
        @DecimalMin(value = "0.00", message = "Unit price must be >= 0")
        BigDecimal unitPrice,

        BigDecimal discountPercent,

        @NotNull(message = "GST rate is required")
        BigDecimal gstRate,

        @NotBlank(message = "Revenue account code is required")
        String accountCode,

        /** Optional item reference. Free-text lines leave this null. */
        UUID itemId,

        /** Optional batch reference (Sprint 26). */
        UUID batchId
) {
    public InvoiceLineRequest {
        if (discountPercent == null) discountPercent = BigDecimal.ZERO;
    }
}
