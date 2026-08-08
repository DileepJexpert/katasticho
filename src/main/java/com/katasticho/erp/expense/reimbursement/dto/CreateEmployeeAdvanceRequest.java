package com.katasticho.erp.expense.reimbursement.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record CreateEmployeeAdvanceRequest(
        @NotNull UUID employeeId,
        @NotNull LocalDate advanceDate,
        @NotNull @DecimalMin("0.01") BigDecimal amount,
        @NotNull UUID paidThroughId,
        String notes
) {}
