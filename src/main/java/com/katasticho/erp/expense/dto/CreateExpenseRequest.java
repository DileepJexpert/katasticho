package com.katasticho.erp.expense.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record CreateExpenseRequest(
        @NotNull(message = "Expense date is required")
        LocalDate expenseDate,

        @NotNull(message = "Expense account is required")
        UUID accountId,

        String category,
        String description,

        @NotNull(message = "Amount is required")
        @DecimalMin(value = "0.01", message = "Amount must be positive")
        BigDecimal amount,

        /** GST rate applied on amount. 0 / 5 / 12 / 18 / 28. Defaults to 0. */
        BigDecimal gstRate,

        String currency,

        /** Vendor contact (VENDOR or BOTH). Optional — cash spend without a vendor is fine. */
        UUID contactId,

        @NotNull(message = "Payment mode is required")
        String paymentMode,

        @NotNull(message = "Paid-through account is required")
        UUID paidThroughId,

        boolean billable,
        UUID projectId,
        UUID customerContactId,

        String receiptUrl,

        /** Optional tax group. If null, resolved from gstRate. */
        UUID taxGroupId
) {}
