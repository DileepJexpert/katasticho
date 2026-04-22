package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record CashFlowResponse(
        LocalDate from,
        LocalDate to,
        BigDecimal cashIn,
        BigDecimal cashOut,
        BigDecimal netCashFlow,
        String currency
) {}
