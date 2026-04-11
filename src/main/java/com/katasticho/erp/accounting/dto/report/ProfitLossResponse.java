package com.katasticho.erp.accounting.dto.report;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record ProfitLossResponse(
        LocalDate startDate,
        LocalDate endDate,
        String currency,
        BigDecimal totalRevenue,
        BigDecimal totalExpenses,
        BigDecimal netProfit,
        List<AccountLine> revenueAccounts,
        List<AccountLine> expenseAccounts
) {
    public record AccountLine(
            UUID accountId,
            String accountCode,
            String accountName,
            BigDecimal amount
    ) {}
}
