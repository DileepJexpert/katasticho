package com.katasticho.erp.organisation.dto;

import java.time.Instant;
import java.util.UUID;

public record BranchResponse(
        UUID id,
        String code,
        String name,
        String addressLine1,
        String addressLine2,
        String city,
        String state,
        String stateCode,
        String postalCode,
        String country,
        String gstin,
        boolean isDefault,
        boolean active,
        Instant createdAt
) {}
