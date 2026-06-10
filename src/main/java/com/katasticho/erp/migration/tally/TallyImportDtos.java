package com.katasticho.erp.migration.tally;

import java.util.List;
import java.util.Map;

/** Preview/commit payloads for the Tally master import. */
public final class TallyImportDtos {

    private TallyImportDtos() {}

    /** One parsed master row and what the import will do with it. */
    public record RowPlan(
            String tallyName,
            String tallyGroup,
            String becomes,     // CUSTOMER / VENDOR / ACCOUNT_ASSET / ... / ITEM
            String action,      // CREATE / SKIP_EXISTS / SKIP
            String detail
    ) {}

    public record TallyImportPreview(
            int customers,
            int vendors,
            int accounts,
            int items,
            int skipped,
            List<RowPlan> rows
    ) {}

    public record RowError(String tallyName, String error) {}

    public record TallyImportResult(
            int customersCreated,
            int vendorsCreated,
            int accountsCreated,
            int itemsCreated,
            int skipped,
            List<RowError> errors
    ) {}

    // ── Voucher (Day Book) import ───────────────────────────────────────

    public record VoucherPlan(
            String voucherType,
            String voucherNumber,
            String date,
            String partyName,
            String narration,
            int ledgerEntries,
            String action,      // JOURNAL / SKIP_UNRESOLVED
            String detail,
            List<String> warnings
    ) {}

    public record VoucherImportPreview(
            int total,
            int importable,
            int skipped,
            Map<String, Integer> byType,
            List<VoucherPlan> vouchers
    ) {}

    public record VoucherImportResult(
            int journalsCreated,
            int skipped,
            Map<String, Integer> byType,
            List<RowError> errors
    ) {}

    // ── CA Bridge: Trial Balance verification ───────────────────────────

    /** One ledger row parsed from a Tally Trial Balance XML export. */
    public record TallyTbLine(
            String ledgerName,
            java.math.BigDecimal debit,
            java.math.BigDecimal credit
    ) {}

    /**
     * One account compared between our books and Tally's TB.
     * {@code status}: MATCHED / MISMATCH / MISSING_IN_BOOKS / MISSING_IN_TALLY.
     */
    public record TbVerificationLine(
            String name,
            java.math.BigDecimal ourBalance,    // signed: + debit, − credit
            java.math.BigDecimal tallyBalance,  // signed: + debit, − credit
            java.math.BigDecimal difference,    // our − tally
            String status
    ) {}

    public record TbVerificationResult(
            String asOfDate,
            int matched,
            int mismatched,
            int missingInBooks,   // in Tally, not in our books
            int missingInTally,   // in our books, not in Tally
            boolean balancesMatch,
            java.math.BigDecimal ourTotalDebit,
            java.math.BigDecimal ourTotalCredit,
            java.math.BigDecimal tallyTotalDebit,
            java.math.BigDecimal tallyTotalCredit,
            List<TbVerificationLine> lines
    ) {}

    // ── CA Bridge: Tally voucher XML export ─────────────────────────────

    public record TallyExportSummary(
            String fromDate,
            String toDate,
            int voucherCount,
            Map<String, Integer> byType
    ) {}
}
