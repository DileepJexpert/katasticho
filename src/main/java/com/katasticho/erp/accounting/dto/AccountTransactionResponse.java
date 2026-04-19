package com.katasticho.erp.accounting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record AccountTransactionResponse(
        UUID lineId,
        UUID journalEntryId,
        String entryNumber,
        LocalDate effectiveDate,
        String sourceModule,
        String entryDescription,
        String lineDescription,
        BigDecimal debit,
        BigDecimal credit,
        String currency,
        BigDecimal baseDebit,
        BigDecimal baseCredit
) {}
