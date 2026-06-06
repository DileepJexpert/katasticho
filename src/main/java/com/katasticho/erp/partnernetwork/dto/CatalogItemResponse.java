package com.katasticho.erp.partnernetwork.dto;

import com.katasticho.erp.partnernetwork.entity.PublishedCatalogItem;

import java.math.BigDecimal;
import java.util.UUID;

public record CatalogItemResponse(
    UUID id,
    UUID sellerOrgId,
    UUID itemId,
    UUID drugMasterId,
    String displayName,
    String publishedSku,
    String hsnCode,
    String manufacturer,
    String packSize,
    String category,
    String description,
    BigDecimal publishedMrp,
    BigDecimal publishedPtr,
    BigDecimal minOrderQty,
    String availabilityStatus,
    boolean isActive
) {
    public static CatalogItemResponse from(PublishedCatalogItem item) {
        return new CatalogItemResponse(
            item.getId(), item.getOrgId(), item.getItemId(), item.getDrugMasterId(),
            item.getDisplayName(), item.getPublishedSku(), item.getHsnCode(),
            item.getManufacturer(), item.getPackSize(), item.getCategory(),
            item.getDescription(), item.getPublishedMrp(), item.getPublishedPtr(),
            item.getMinOrderQty(), item.getAvailabilityStatus(), item.isActive()
        );
    }
}
