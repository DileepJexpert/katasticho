package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.util.List;

public record ApSummaryResponse(
        BigDecimal totalOutstanding,
        int overdueCount,
        BigDecimal dueThisWeek,
        int dueThisWeekCount,
        List<BranchPurchaseRow> byBranch
) {}
