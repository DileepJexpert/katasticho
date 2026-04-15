package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Per-branch revenue rollup. sharePercent is pre-computed server-side so
 * the client never has to divide totals to render the percentage badges.
 */
public record BranchSalesRow(
        UUID branchId,
        String branchCode,
        String branchName,
        BigDecimal revenue,
        BigDecimal sharePercent
) {}
