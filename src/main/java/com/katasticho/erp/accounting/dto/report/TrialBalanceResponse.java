package com.katasticho.erp.accounting.dto.report;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record TrialBalanceResponse(
        LocalDate asOfDate,
        String currency,
        BigDecimal totalDebit,
        BigDecimal totalCredit,
        boolean isBalanced,
        List<TrialBalanceLine> lines
) {
    public record TrialBalanceLine(
            UUID accountId,
            String accountCode,
            String accountName,
            String accountType,
            BigDecimal debit,
            BigDecimal credit,
            BigDecimal balance
    ) {}
}
