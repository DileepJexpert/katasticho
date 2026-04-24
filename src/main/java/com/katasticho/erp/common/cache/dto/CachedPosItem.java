package com.katasticho.erp.common.cache.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CachedPosItem(
        UUID itemId,
        String name,
        String sku,
        String barcode,
        BigDecimal salePrice,
        BigDecimal mrp,
        BigDecimal purchasePrice,
        UUID defaultTaxGroupId,
        String taxGroupName,
        String hsnCode,
        String unitOfMeasure,
        BigDecimal currentStock,
        boolean weightBasedBilling,
        boolean trackBatches
) {}
