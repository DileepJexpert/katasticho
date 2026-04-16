package com.katasticho.erp.expense.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * All fields nullable — only non-null fields are applied.
 * Updating amount/tax/accounts reverses the journal and reposts.
 */
public record UpdateExpenseRequest(
        LocalDate expenseDate,
        UUID accountId,
        String category,
        String description,
        BigDecimal amount,
        BigDecimal gstRate,
        UUID contactId,
        String paymentMode,
        UUID paidThroughId,
        Boolean billable,
        UUID projectId,
        UUID customerContactId,
        String receiptUrl,
        UUID taxGroupId
) {}
