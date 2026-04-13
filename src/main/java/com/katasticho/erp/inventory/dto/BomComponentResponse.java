package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.BomComponent;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * BOM row as returned by the composite-item detail endpoint.
 *
 * <p>{@code childSku} and {@code childName} are only populated by the
 * enriched listing path ({@code BomService.listComponentsEnriched})
 * which does a single batch lookup against {@code ItemRepository}. The
 * basic {@link #from(BomComponent)} factory leaves them null for
 * callers that don't need display fields — e.g. the single-row
 * response from {@code POST /{parentId}/bom}.
 */
public record BomComponentResponse(
        UUID id,
        UUID parentItemId,
        UUID childItemId,
        String childSku,
        String childName,
        BigDecimal quantity
) {
    public static BomComponentResponse from(BomComponent row) {
        return new BomComponentResponse(
                row.getId(),
                row.getParentItemId(),
                row.getChildItemId(),
                null,
                null,
                row.getQuantity());
    }

    public static BomComponentResponse from(BomComponent row, String childSku, String childName) {
        return new BomComponentResponse(
                row.getId(),
                row.getParentItemId(),
                row.getChildItemId(),
                childSku,
                childName,
                row.getQuantity());
    }
}
