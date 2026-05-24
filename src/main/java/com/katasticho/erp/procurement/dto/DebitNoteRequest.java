package com.katasticho.erp.procurement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record DebitNoteRequest(
        @NotNull UUID supplierId,
        @NotBlank String returnReason,
        @NotNull LocalDate noteDate,
        UUID referenceBillId,
        String notes,
        @NotEmpty List<DebitNoteLineRequest> lines
) {}
