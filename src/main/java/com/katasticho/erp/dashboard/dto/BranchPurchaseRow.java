package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;

public record BranchPurchaseRow(
        java.util.UUID branchId,
        String branchCode,
        String branchName,
        BigDecimal purchases,
        BigDecimal sharePercent
) {}
