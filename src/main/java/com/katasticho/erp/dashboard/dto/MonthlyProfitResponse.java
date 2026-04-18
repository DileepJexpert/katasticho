package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MonthlyProfitResponse(
        LocalDate from,
        LocalDate to,
        BigDecimal revenue,
        BigDecimal cogs,
        BigDecimal grossProfit,
        String currency
) {}
