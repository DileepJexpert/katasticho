package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record CashFlowStatement(
    LocalDate startDate,
    LocalDate endDate,
    List<CashFlowStatement.DailyFlow> flows,
    BigDecimal openingBalance,
    BigDecimal closingBalance
) {
    public record DailyFlow(
        LocalDate date,
        BigDecimal salesInflow,
        BigDecimal arCollection,
        BigDecimal cogsOutflow,
        BigDecimal apPayment,
        BigDecimal netFlow
    ) {}
}
