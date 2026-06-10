package com.katasticho.erp.migration.tally;

import java.util.List;

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
}
