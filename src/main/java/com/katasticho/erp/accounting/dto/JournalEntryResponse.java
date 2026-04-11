package com.katasticho.erp.accounting.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record JournalEntryResponse(
        UUID id,
        String entryNumber,
        LocalDate effectiveDate,
        Instant createdAt,
        String description,
        String sourceModule,
        String status,
        boolean isReversal,
        boolean isReversed,
        UUID reversalOfId,
        int periodYear,
        int periodMonth,
        List<LineResponse> lines
) {
    public record LineResponse(
            UUID id,
            UUID accountId,
            String accountCode,
            String accountName,
            String description,
            BigDecimal debit,
            BigDecimal credit,
            String currency,
            BigDecimal exchangeRate,
            BigDecimal baseDebit,
            BigDecimal baseCredit,
            String taxComponentCode
    ) {}
}
