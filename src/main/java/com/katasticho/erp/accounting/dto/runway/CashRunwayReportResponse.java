package com.katasticho.erp.accounting.dto.runway;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record CashRunwayReportResponse(
        LocalDate asOfDate,
        String baseCurrency,
        BigDecimal currentLiquidCash,
        BigDecimal safetyBufferAmount,
        Double runwayWeeks,
        BigDecimal minProjectedBalance,
        Integer minBalanceWeek,
        BigDecimal totalInflows13W,
        BigDecimal totalOutflows13W,
        BigDecimal netChange13W,
        int deficitWeeksCount,
        List<String> deficitAlerts,
        List<CashRunwayWeeklyBucket> weeklyBuckets,
        WorkingCapitalMetrics workingCapitalHealth
) {
    public record WorkingCapitalMetrics(
            BigDecimal projectedCurrentRatio,
            BigDecimal projectedQuickRatio,
            int estimatedCashConversionDays,
            String liquidityStatus
    ) {}
}