package com.katasticho.erp.contact.dto;

import java.math.BigDecimal;
import java.util.List;

public record ContactImportPreview(
        int totalRows,
        int validRows,
        int errorRows,
        List<RowPreview> rows
) {
    public record RowPreview(
            int rowNumber,
            String displayName,
            String contactType,
            String phone,
            String email,
            String status,   // OK | ERROR
            String error     // null when status == OK
    ) {}
}
