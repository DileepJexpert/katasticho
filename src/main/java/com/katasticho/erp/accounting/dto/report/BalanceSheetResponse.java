package com.katasticho.erp.accounting.dto.report;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record BalanceSheetResponse(
        LocalDate asOfDate,
        String currency,
        BigDecimal totalAssets,
        BigDecimal totalLiabilities,
        BigDecimal totalEquity,
        BigDecimal retainedEarnings,
        boolean isBalanced,
        List<AccountLine> assetAccounts,
        List<AccountLine> liabilityAccounts,
        List<AccountLine> equityAccounts
) {
    public record AccountLine(
            UUID accountId,
            String accountCode,
            String accountName,
            BigDecimal amount
    ) {}
}
