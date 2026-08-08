package com.katasticho.erp.expense.reimbursement.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record CreateReimbursementRequest(
        @NotNull LocalDate expenseDate,
        UUID employeeId,
        @NotNull UUID accountId,
        String category,
        @NotBlank String description,
        @NotNull @DecimalMin("0.01") BigDecimal amount,
        BigDecimal gstRate,
        UUID taxGroupId,
        String receiptUrl,
        String notes
) {}
