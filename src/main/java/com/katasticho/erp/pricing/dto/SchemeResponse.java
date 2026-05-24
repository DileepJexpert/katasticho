package com.katasticho.erp.pricing.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record SchemeResponse(
    UUID id,
    String name,
    String schemeType,
    UUID itemId,
    String itemName,
    BigDecimal buyQuantity,
    BigDecimal freeQuantity,
    BigDecimal discountPercent,
    BigDecimal minOrderQuantity,
    LocalDate validFrom,
    LocalDate validTo,
    UUID supplierId,
    String supplierName,
    boolean active,
    Instant createdAt
) {}
