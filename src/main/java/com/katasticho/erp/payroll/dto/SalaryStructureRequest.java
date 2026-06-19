package com.katasticho.erp.payroll.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record SalaryStructureRequest(
    @NotNull LocalDate effectiveFrom,
    BigDecimal ctcMonthly,
    BigDecimal grossMonthly,
    /**
     * Pay model — SALARY (default), HOURLY, or PIECE_RATE. The latter
     * two drive the production→payroll bridge (tracker #57) which adds
     * a LABOR_PAY earning from the worker's completed job cards.
     */
    String payType,
    BigDecimal hourlyRate,
    BigDecimal pieceRate,
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
