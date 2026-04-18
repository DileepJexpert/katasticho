package com.katasticho.erp.ar.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateCreditNoteRequest(
        @NotNull(message = "Contact ID is required")
        UUID contactId,

        UUID invoiceId,

        @NotNull(message = "Credit note date is required")
        LocalDate creditNoteDate,

        @NotBlank(message = "Reason is required")
        String reason,

        String placeOfSupply,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<CreditNoteLineRequest> lines
) {}
