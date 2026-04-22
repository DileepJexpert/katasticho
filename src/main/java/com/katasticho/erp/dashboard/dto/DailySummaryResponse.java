package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record DailySummaryResponse(
        TodaySnapshot today,
        List<DailyRow> daily,
        WeekComparison thisWeek,
        String currency
) {
    public record TodaySnapshot(
            BigDecimal totalSale,
            BigDecimal totalCost,
            BigDecimal earning,
            BigDecimal cashUpiIn,
            BigDecimal creditSale,
            int billCount
    ) {}

    public record DailyRow(
            LocalDate date,
            BigDecimal sale,
            BigDecimal cost,
            BigDecimal earning
    ) {}

    public record WeekComparison(
            BigDecimal totalSale,
            BigDecimal totalEarning,
            BigDecimal vsLastWeekSalePct,
            BigDecimal vsLastWeekEarningPct
    ) {}
}
