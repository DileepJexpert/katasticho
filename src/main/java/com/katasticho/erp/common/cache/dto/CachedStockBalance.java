package com.katasticho.erp.common.cache.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CachedStockBalance(
        UUID itemId,
        UUID warehouseId,
        BigDecimal quantityOnHand,
        BigDecimal reservedQty,
        BigDecimal averageCost,
        BigDecimal reorderLevel
) {}
