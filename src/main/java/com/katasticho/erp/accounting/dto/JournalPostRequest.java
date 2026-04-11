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

        boolean autoPost
) {
    public JournalPostRequest {
        if (lines == null) lines = List.of();
    }
}
