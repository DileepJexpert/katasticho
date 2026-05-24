package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record ShortbookItemResponse(
        UUID itemId,
        String itemName,
        String sku,
        String hsnCode,
        BigDecimal currentStock,
        BigDecimal reorderLevel,
        BigDecimal reorderQuantity,
        BigDecimal backordered,
        BigDecimal suggestOrderQty,
        String reason // "BACKORDER", "LOW_STOCK", or "BOTH"
) {}
