package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record LowStockAlertReport(
    LocalDate generatedAt,
    int itemCount,
    BigDecimal estimatedPurchaseCost,
    List<LowStockAlertReport.Item> items
) {
    public record Item(
        UUID itemId,
        String itemName,
        String sku,
        BigDecimal currentStock,
        BigDecimal reorderLevel,
        BigDecimal reorderQuantity,
        BigDecimal deficitQty,
        UUID supplierId,
        String supplierName,
        BigDecimal estimatedCost
    ) {}
}
