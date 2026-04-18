package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record RevenueTrendResponse(
        LocalDate from,
        LocalDate to,
        int days,
        BigDecimal totalRevenue,
        String currency,
        List<DailyPoint> trend
) {
    public record DailyPoint(LocalDate date, BigDecimal revenue) {}
}
