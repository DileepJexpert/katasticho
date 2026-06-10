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
}
