package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record SalaryStructureRequest(
    @NotNull LocalDate effectiveFrom,
    BigDecimal ctcMonthly,
    BigDecimal grossMonthly,
    List<ComponentLine> lines
) {
    public record ComponentLine(
        @NotNull String componentCode,
        @NotNull String calculationType,
        BigDecimal amount,
        BigDecimal percentage,
        String baseComponentCode
    ) {}
}
