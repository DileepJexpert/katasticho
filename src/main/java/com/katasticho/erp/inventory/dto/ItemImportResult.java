package com.katasticho.erp.inventory.dto;

import java.util.List;

/**
 * Result of a bulk item import. Returned to the UI so the user knows
 * how many rows were created vs skipped, with per-row error messages.
 */
public record ItemImportResult(
        int totalRows,
        int created,
        int skipped,
        List<RowError> errors
) {
    public record RowError(int rowNumber, String sku, String message) {}
}
