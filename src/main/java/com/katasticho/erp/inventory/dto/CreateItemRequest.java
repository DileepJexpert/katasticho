package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.ItemType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record CreateItemRequest(
        @NotBlank(message = "SKU is required")
        @Size(max = 50, message = "SKU must be at most 50 characters")
        String sku,

        @NotBlank(message = "Name is required")
        @Size(max = 255)
        String name,

        String description,

        @NotNull(message = "Item type is required")
        ItemType itemType,

        String category,
        String brand,

        @Size(max = 10)
        String hsnCode,

        @Size(max = 20)
        String unitOfMeasure,

        @DecimalMin(value = "0.00", message = "Purchase price must be >= 0")
        BigDecimal purchasePrice,

        @DecimalMin(value = "0.00", message = "Sale price must be >= 0")
        BigDecimal salePrice,

        @DecimalMin(value = "0.00", message = "MRP must be >= 0")
        BigDecimal mrp,

        @DecimalMin(value = "0.00", message = "GST rate must be >= 0")
        BigDecimal gstRate,

        Boolean trackInventory,

        /**
         * Opt into FEFO/batch tracking for this item. When true, every
         * stock movement MUST reference a batch via {@code stock_batch}.
         * Defaults to false.
         */
        Boolean trackBatches,

        @DecimalMin(value = "0.00", message = "Reorder level must be >= 0")
        BigDecimal reorderLevel,

        @DecimalMin(value = "0.00", message = "Reorder quantity must be >= 0")
        BigDecimal reorderQuantity,

        String revenueAccountCode,
        String cogsAccountCode,
        String inventoryAccountCode,

        /** Initial on-hand quantity. If &gt; 0, an OPENING movement is recorded. */
        @DecimalMin(value = "0.00", message = "Opening stock must be >= 0")
        BigDecimal openingStock,

        /** Optional warehouse for the opening movement. Defaults to org's default warehouse. */
        java.util.UUID openingWarehouseId
) {}
