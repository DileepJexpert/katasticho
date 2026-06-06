package com.katasticho.erp.payroll.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record PayrollRunResponse(
    UUID id,
    LocalDate periodStart,
    LocalDate periodEnd,
    String status,
    int employeeCount,
    BigDecimal grossTotal,
    BigDecimal deductionTotal,
    BigDecimal employerContributionTotal,
    BigDecimal netPayTotal,
    UUID journalEntryId,
    Instant approvedAt,
    Instant postedAt
) {}
