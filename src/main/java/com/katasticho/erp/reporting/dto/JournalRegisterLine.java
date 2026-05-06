package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record JournalRegisterLine(
    String entryNumber,
    LocalDate journalDate,
    String description,
    String sourceModule,
    UUID sourceId,
    int lineCount,
    BigDecimal totalDebit,
    BigDecimal totalCredit,
    List<JournalRegisterLine.Detail> details
) {
    public record Detail(
        String accountCode,
        String accountName,
        BigDecimal debit,
        BigDecimal credit
    ) {}
}
