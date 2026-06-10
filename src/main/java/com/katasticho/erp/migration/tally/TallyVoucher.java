package com.katasticho.erp.migration.tally;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * A single voucher parsed from a Tally Day Book XML export.
 *
 * <p>Each voucher contains one or more {@link LedgerEntry} rows that form a
 * balanced double-entry (total debits = total credits). Tally's sign convention:
 * <b>positive = debit, negative = credit.</b>
 *
 * <p>The importer resolves each ledger name to a chart-of-accounts code and
 * posts a journal entry.
 */
public record TallyVoucher(
        String voucherType,
        String voucherNumber,
        LocalDate date,
        String partyLedgerName,
        String narration,
        List<LedgerEntry> ledgerEntries
) {
    public record LedgerEntry(
            String ledgerName,
            BigDecimal amount
    ) {}
}
