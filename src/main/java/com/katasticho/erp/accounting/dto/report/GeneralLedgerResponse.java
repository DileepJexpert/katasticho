package com.katasticho.erp.accounting.dto.report;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record GeneralLedgerResponse(
        UUID accountId,
        String accountCode,
        String accountName,
        String accountType,
        LocalDate startDate,
        LocalDate endDate,
        String currency,
        BigDecimal openingBalance,
        BigDecimal closingBalance,
        BigDecimal totalDebit,
        BigDecimal totalCredit,
        List<LedgerEntry> entries
) {
    public record LedgerEntry(
            UUID journalEntryId,
            String entryNumber,
            LocalDate effectiveDate,
            String description,
            String sourceModule,
            BigDecimal debit,
            BigDecimal credit,
            BigDecimal runningBalance
    ) {}
}
