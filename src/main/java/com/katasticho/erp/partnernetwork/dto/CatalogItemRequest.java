package com.katasticho.erp.partnernetwork.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CatalogItemRequest(
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
    String availabilityStatus
) {}
