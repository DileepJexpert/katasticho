package com.katasticho.erp.ai.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Structured bill data (typically the reviewed output of {@code /ai/scan-bill})
 * that the AI drafting layer turns into a DRAFT purchase bill the human can
 * approve-and-post in one tap.
 *
 * <p>This is the "draft, don't type" entry point: the client sends what was
 * extracted (and optionally edited) from a scanned bill, and the backend does
 * the accounting work — vendor resolution, item matching, HSN&rarr;GST
 * inference, account mapping — instead of the operator filling a blank form.
 */
public record BillDraftFromScanRequest(
        String vendorName,
        String vendorGstin,
        /** Two-char state code (place of supply); falls back to org state when null. */
        String vendorStateCode,
        String invoiceNumber,
        LocalDate billDate,
        LocalDate dueDate,
        String notes,
        /** Extraction confidence 0..1, carried through to the suggestion. */
        Double confidence,
        @NotEmpty(message = "At least one line is required")
        @Valid
        List<ScanLine> lines
) {
    public record ScanLine(
            String description,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal unitPrice,
            /** GST percent read from the bill; when null/zero we infer from HSN. */
            BigDecimal gstRate,
            BigDecimal discountPercent
    ) {}
}
