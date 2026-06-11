package com.katasticho.erp.migration.tally;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * A single voucher parsed from a Tally Day Book XML export.
 *
 * <p>Each voucher contains one or more {@link LedgerEntry} rows that form a
 * balanced double-entry (total debits = total credits).
 *
 * <p><b>Sign convention:</b> Tally's raw XML writes a debit as a NEGATIVE
 * {@code AMOUNT} ({@code ISDEEMEDPOSITIVE=Yes}) and a credit as POSITIVE
 * ({@code ISDEEMEDPOSITIVE=No}). The parser normalizes this so that here
 * {@code amount} is <b>positive = debit, negative = credit</b>.
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
    /** {@code amount}: normalized to positive = debit, negative = credit. */
    public record LedgerEntry(
            String ledgerName,
            BigDecimal amount
    ) {}
}
