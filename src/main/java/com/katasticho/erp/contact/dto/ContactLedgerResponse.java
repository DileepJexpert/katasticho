package com.katasticho.erp.contact.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record ContactLedgerResponse(
        UUID contactId,
        String contactName,
        String contactType,
        BigDecimal openingBalance,
        BigDecimal closingBalance,
        BigDecimal totalInvoiced,
        BigDecimal totalPaid,
        List<LedgerEntry> entries
) {
    public record LedgerEntry(
            LocalDate date,
            String type,
            String number,
            UUID referenceId,
            String description,
            BigDecimal debit,
            BigDecimal credit,
            BigDecimal runningBalance
    ) {}
}
