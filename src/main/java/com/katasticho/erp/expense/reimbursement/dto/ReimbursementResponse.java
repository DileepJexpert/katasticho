package com.katasticho.erp.expense.reimbursement.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record ReimbursementResponse(
        UUID id,
        UUID employeeId,
        String employeeName,
        UUID expenseId,
        LocalDate expenseDate,
        UUID accountId,
        String accountCode,
        String accountName,
        String category,
        String description,
        BigDecimal amount,
        String status,
        BigDecimal advanceApplied,
        BigDecimal payableAmount,
        BigDecimal paidAmount,
        String receiptUrl,
        String notes,
        UUID approvedBy,
        Instant approvedAt,
        UUID rejectedBy,
        Instant rejectedAt,
        String rejectionReason,
        UUID paidThroughId,
        Instant paidAt,
        Instant createdAt
) {}
