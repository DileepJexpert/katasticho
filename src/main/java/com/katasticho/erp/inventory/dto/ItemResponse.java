package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.ItemType;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record ItemResponse(
        UUID id,
        String sku,
        String name,
        String description,
        ItemType itemType,
        String category,
        String brand,
        String hsnCode,
        String unitOfMeasure,
        BigDecimal purchasePrice,
        BigDecimal salePrice,
        BigDecimal mrp,
        BigDecimal gstRate,
        boolean trackInventory,
        boolean trackBatches,
        BigDecimal reorderLevel,
        BigDecimal reorderQuantity,
        String revenueAccountCode,
        String cogsAccountCode,
        String inventoryAccountCode,
        boolean active,
        BigDecimal totalOnHand,
        Instant createdAt
) {}
