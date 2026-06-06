package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public record CreatePayrollRunRequest(
    @NotNull LocalDate periodStart,
    @NotNull LocalDate periodEnd
) {}
