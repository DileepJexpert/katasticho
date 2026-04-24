package com.katasticho.erp.common.cache.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CachedItemPrice(
        UUID itemId,
        String name,
        String sku,
        String barcode,
        BigDecimal salePrice,
        BigDecimal purchasePrice,
        BigDecimal mrp,
        BigDecimal gstRate,
        UUID defaultTaxGroupId,
        String hsnCode,
        String unitOfMeasure,
        boolean active
) {}
