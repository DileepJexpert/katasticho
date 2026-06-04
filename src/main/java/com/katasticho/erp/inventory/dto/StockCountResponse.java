package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record StockCountResponse(
        UUID id,
        String countNumber,
        UUID warehouseId,
        String warehouseName,
        LocalDate countDate,
        String status,
        String notes,
        Instant postedAt,
        int lineCount,
        int varianceCount,
        List<StockCountLineResponse> lines,
        Instant createdAt
) {
    public record StockCountLineResponse(
            UUID id,
            UUID itemId,
            String itemName,
            String sku,
            BigDecimal expectedQuantity,
            BigDecimal countedQuantity,
            BigDecimal variance,
            String notes
    ) {}
}
