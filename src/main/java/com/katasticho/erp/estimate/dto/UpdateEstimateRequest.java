package com.katasticho.erp.estimate.dto;

import jakarta.validation.Valid;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Partial update of a DRAFT / SENT estimate. Nullable fields are left
 * untouched. If {@code lines} is non-null the entire line list is
 * replaced (simpler than diffing).
 */
public record UpdateEstimateRequest(
        UUID contactId,
        LocalDate estimateDate,
        LocalDate expiryDate,
        String referenceNumber,
        String subject,
        String notes,
        String terms,

        @Valid
        List<EstimateLineRequest> lines
) {}
