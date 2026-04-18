package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;

public record ArSummaryResponse(
        BigDecimal totalOutstanding,
        int overdueCount,
        BigDecimal dueThisWeek,
        int dueThisWeekCount,
        String currency
) {}
