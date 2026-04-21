package com.katasticho.erp.contact.dto;

import java.util.List;

public record ContactImportResult(
        int totalRows,
        int created,
        int skipped,
        List<RowError> errors
) {
    public record RowError(int rowNumber, String displayName, String message) {}
}
