package com.katasticho.erp.procurement.dto;

import java.time.Instant;
import java.util.UUID;

public record SupplierResponse(
        UUID id,
        String name,
        String gstin,
        String pan,
        String phone,
        String email,
        String addressLine1,
        String addressLine2,
        String city,
        String state,
        String stateCode,
        String postalCode,
        String country,
        Integer paymentTermsDays,
        String notes,
        boolean active,
        Instant createdAt
) {}
