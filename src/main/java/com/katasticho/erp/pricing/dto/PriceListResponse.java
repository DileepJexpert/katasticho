package com.katasticho.erp.pricing.dto;

import com.katasticho.erp.pricing.entity.PriceList;

import java.time.Instant;
import java.util.UUID;

public record PriceListResponse(
        UUID id,
        String name,
        String description,
        String currency,
        boolean isDefault,
        boolean active,
        Instant createdAt
) {
    public static PriceListResponse from(PriceList list) {
        return new PriceListResponse(
                list.getId(),
                list.getName(),
                list.getDescription(),
                list.getCurrency(),
                list.isDefault(),
                list.isActive(),
                list.getCreatedAt());
    }
}
