package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.Uom;
import com.katasticho.erp.inventory.entity.UomCategory;

import java.util.UUID;

public record UomResponse(
        UUID id,
        String name,
        String abbreviation,
        UomCategory category,
        boolean base,
        boolean active
) {
    public static UomResponse from(Uom u) {
        return new UomResponse(
                u.getId(),
                u.getName(),
                u.getAbbreviation(),
                u.getCategory(),
                u.isBase(),
                u.isActive());
    }
}
