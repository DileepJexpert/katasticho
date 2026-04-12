package com.katasticho.erp.inventory.dto;

import java.time.Instant;
import java.util.UUID;

public record WarehouseResponse(
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
        boolean isDefault,
        boolean active,
        Instant createdAt
) {}
