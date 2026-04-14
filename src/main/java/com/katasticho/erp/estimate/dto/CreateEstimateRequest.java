package com.katasticho.erp.estimate.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateEstimateRequest(
        @NotNull(message = "Contact is required")
        UUID contactId,

        @NotNull(message = "Estimate date is required")
        LocalDate estimateDate,

        LocalDate expiryDate,

        String currency,
        String referenceNumber,
        String subject,
        String notes,
        String terms,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<EstimateLineRequest> lines
) {}
