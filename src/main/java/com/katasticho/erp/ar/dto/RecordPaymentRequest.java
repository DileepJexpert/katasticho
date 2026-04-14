package com.katasticho.erp.ar.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record RecordPaymentRequest(
        @NotNull(message = "Invoice ID is required")
        UUID invoiceId,

        /** F6: unified contact FK — optional, derived from invoice if omitted. */
        UUID contactId,

        @NotNull(message = "Payment date is required")
        LocalDate paymentDate,

        @NotNull(message = "Amount is required")
        @DecimalMin(value = "0.01", message = "Amount must be positive")
        BigDecimal amount,

        @NotBlank(message = "Payment method is required")
        String paymentMethod,

        String referenceNumber,
        String bankAccount,
        String notes
) {}
