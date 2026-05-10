package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record StockSummaryReport(
    LocalDate asOfDate,
    BigDecimal totalInventoryValue,
    int itemCount,
    int lowStockCount,
    int outOfStockCount,
    List<StockSummaryReport.Item> items
) {
    public record Item(
        UUID itemId,
        String itemName,
        String sku,
        String unit,
        BigDecimal quantityOnHand,
        BigDecimal purchasePrice,
        BigDecimal inventoryValue,
        BigDecimal reorderLevel,
        String status,
        BigDecimal averageCost,
        Instant lastMovementAt
    ) {}
}
