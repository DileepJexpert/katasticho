package com.katasticho.erp.accounting.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record JournalPostRequest(
        @NotNull(message = "Effective date is required")
        LocalDate effectiveDate,

        @NotBlank(message = "Description is required")
        String description,

        @NotBlank(message = "Source module is required")
        String sourceModule,

        UUID sourceId,

        @NotEmpty(message = "Journal lines are required")
        @Valid
        List<JournalLineRequest> lines,

        boolean autoPost,

        /** Post-dated voucher: stays DRAFT until effectiveDate, then auto-posts (daily job). */
        boolean postDated
) {
    /** Compact constructor for the common (non-post-dated) case. */
    public JournalPostRequest(LocalDate effectiveDate, String description, String sourceModule,
                              UUID sourceId, List<JournalLineRequest> lines, boolean autoPost) {
        this(effectiveDate, description, sourceModule, sourceId, lines, autoPost, false);
    }

    public JournalPostRequest {
        if (lines == null) lines = List.of();
    }
}
