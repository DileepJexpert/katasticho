package com.katasticho.erp.expense.reimbursement.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record EmployeeAdvanceResponse(
        UUID id,
        UUID employeeId,
        String employeeName,
        LocalDate advanceDate,
        BigDecimal amount,
        BigDecimal settledAmount,
        BigDecimal openAmount,
        String status,
        UUID paidThroughId,
        UUID journalEntryId,
        String notes
) {}
