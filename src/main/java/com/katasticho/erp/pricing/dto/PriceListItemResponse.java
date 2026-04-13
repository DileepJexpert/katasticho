package com.katasticho.erp.pricing.dto;

import com.katasticho.erp.pricing.entity.PriceListItem;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Tier row as returned by the price-list detail endpoint.
 *
 * <p>{@code itemName} and {@code itemSku} are optional and populated
 * only by the enriched listing path ({@code PriceListService.listItemsEnriched})
 * which does a single batch lookup against {@code ItemRepository}. The
 * basic {@link #from(PriceListItem)} factory leaves them null for callers
 * that don't need the display fields (e.g. the single-row response from
 * {@code POST /{id}/items}).
 */
public record PriceListItemResponse(
        UUID id,
        UUID priceListId,
        UUID itemId,
        String itemSku,
        String itemName,
        BigDecimal minQuantity,
        BigDecimal price
) {
    public static PriceListItemResponse from(PriceListItem item) {
        return new PriceListItemResponse(
                item.getId(),
                item.getPriceListId(),
                item.getItemId(),
                null,
                null,
                item.getMinQuantity(),
                item.getPrice());
    }

    public static PriceListItemResponse from(
            PriceListItem item, String itemSku, String itemName) {
        return new PriceListItemResponse(
                item.getId(),
                item.getPriceListId(),
                item.getItemId(),
                itemSku,
                itemName,
                item.getMinQuantity(),
                item.getPrice());
    }
}
