package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Result of a bulk item import.
 *
 * <p>{@link #successRows} contains every row that was persisted.
 * {@link #failedRows} contains every row that was skipped — including
 * both validation errors (caught during parse) and runtime errors
 * (caught during DB save / stock movement). Failed rows include the
 * original field values so the UI can present an editable table for
 * the owner to fix and retry.
 */
public record ItemImportResult(
        int totalRows,
        int created,
        int skipped,
        List<SuccessRow> successRows,
        List<FailedRow> failedRows
) {
    /** Minimal summary for a successfully imported row. */
    public record SuccessRow(
            int rowNumber,
            String sku,
            String name,
            String itemType,
            BigDecimal purchasePrice,
            BigDecimal salePrice,
            BigDecimal openingStock
    ) {}

    /**
     * Full row data for a failed row so the owner can edit and retry.
     * All fields reflect what was parsed from the CSV; numeric fields
     * are null when the original cell was blank.
     */
    public record FailedRow(
            int rowNumber,
            String sku,
            String name,
            String itemType,
            String category,
            String hsnCode,
            String unitOfMeasure,
            BigDecimal purchasePrice,
            BigDecimal salePrice,
            BigDecimal gstRate,
            BigDecimal openingStock,
            String errorMessage
    ) {}
}
