package com.katasticho.erp.expense.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record ExpenseResponse(
        UUID id,
        String expenseNumber,
        LocalDate expenseDate,

        UUID accountId,
        String accountCode,
        String accountName,

        String category,
        String description,

        BigDecimal amount,
        BigDecimal taxAmount,
        BigDecimal total,
        String currency,
        BigDecimal gstRate,

        UUID contactId,
        String contactName,

        String paymentMode,
        UUID paidThroughId,
        String paidThroughName,

        boolean billable,
        UUID projectId,
        UUID customerContactId,
        String customerContactName,

        String receiptUrl,
        String status,

        UUID journalEntryId,

        Instant createdAt
) {}
