package com.katasticho.erp.tax.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Flat projection of a payslip line joined to its salary component — used by
 * {@code SalaryTdsService} to aggregate salary-TDS (Form 24Q / Form 16) without
 * an N+1 walk over lazy associations.
 */
public record SalaryTdsLineRow(
        UUID employeeId,
        String componentCode,
        String componentType,
        BigDecimal amount,
        UUID payrollRunId) {
}
