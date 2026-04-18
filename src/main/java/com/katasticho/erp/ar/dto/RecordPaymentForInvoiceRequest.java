package com.katasticho.erp.ar.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record RecordPaymentForInvoiceRequest(
        @NotNull(message = "Amount is required")
        @DecimalMin(value = "0.01", message = "Amount must be positive")
        BigDecimal amount,

        @NotBlank(message = "Payment method is required")
        String paymentMethod,

        @NotNull(message = "Payment date is required")
        LocalDate paymentDate,

        UUID paidThroughId,
        String referenceNumber,
        String notes
) {}
