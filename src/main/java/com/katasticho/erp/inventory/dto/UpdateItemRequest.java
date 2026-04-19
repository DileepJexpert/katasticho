package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.ItemType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Update payload — does NOT include opening stock fields. Stock changes go
 * through the dedicated stock-adjustment endpoint so every quantity change
 * leaves a stock_movement audit trail.
 */
public record UpdateItemRequest(
        @NotBlank @Size(max = 50) String sku,
        @NotBlank @Size(max = 255) String name,
        String description,
        @NotNull ItemType itemType,
        String category,
        String brand,
        @Size(max = 10) String hsnCode,
        @Size(max = 20) String unitOfMeasure,
        @DecimalMin("0.00") BigDecimal purchasePrice,
        @DecimalMin("0.00") BigDecimal salePrice,
        @DecimalMin("0.00") BigDecimal mrp,
        @DecimalMin("0.00") BigDecimal gstRate,
        Boolean trackInventory,
        Boolean trackBatches,
        @DecimalMin("0.00") BigDecimal reorderLevel,
        @DecimalMin("0.00") BigDecimal reorderQuantity,
        @Size(max = 50) String barcode,
        @Size(max = 100) String manufacturer,
        UUID preferredVendorId,

        BigDecimal weight,
        @Size(max = 10) String weightUnit,
        BigDecimal length,
        BigDecimal width,
        BigDecimal height,
        @Size(max = 10) String dimensionUnit,

        @Size(max = 10) String drugSchedule,
        String composition,
        @Size(max = 50) String dosageForm,
        @Size(max = 50) String packSize,
        @Size(max = 100) String storageCondition,
        Boolean prescriptionRequired,

        String revenueAccountCode,
        String cogsAccountCode,
        String inventoryAccountCode,
        Boolean active
) {}
