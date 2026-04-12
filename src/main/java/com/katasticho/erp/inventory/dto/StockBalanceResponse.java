package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record StockBalanceResponse(
        UUID itemId,
        String itemSku,
        String itemName,
        UUID warehouseId,
        String warehouseName,
        BigDecimal quantityOnHand,
        BigDecimal averageCost,
        BigDecimal reorderLevel,
        boolean lowStock,
        Instant lastMovementAt
) {}
