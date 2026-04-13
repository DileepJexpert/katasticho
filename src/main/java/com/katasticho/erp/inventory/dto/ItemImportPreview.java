package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Dry-run result for bulk item import. The backend parses and validates
 * every row but does NOT persist anything. The UI renders this as a
 * preview table so users can fix mistakes before the actual import.
 *
 * {@code validRows} counts rows whose {@link RowPreview#status()} is
 * {@code OK}; everything else (duplicates, missing required fields, bad
 * numbers) is an error row.
 */
public record ItemImportPreview(
        int totalRows,
        int validRows,
        int errorRows,
        List<RowPreview> rows
) {
    /**
     * One parsed row from the uploaded CSV plus its validation verdict.
     * Numeric fields are already coerced so the client can render them
     * directly (null when the CSV field was blank or unparseable).
     */
    public record RowPreview(
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
            String status,   // OK | ERROR
            String error     // null when status == OK
    ) {}
}
