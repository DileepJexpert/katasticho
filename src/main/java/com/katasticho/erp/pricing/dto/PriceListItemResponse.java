package com.katasticho.erp.pricing.dto;

import com.katasticho.erp.pricing.entity.PriceListItem;

import java.math.BigDecimal;
import java.util.UUID;

public record PriceListItemResponse(
        UUID id,
        UUID priceListId,
        UUID itemId,
        BigDecimal minQuantity,
        BigDecimal price
) {
    public static PriceListItemResponse from(PriceListItem item) {
        return new PriceListItemResponse(
                item.getId(),
                item.getPriceListId(),
                item.getItemId(),
                item.getMinQuantity(),
                item.getPrice());
    }
}
