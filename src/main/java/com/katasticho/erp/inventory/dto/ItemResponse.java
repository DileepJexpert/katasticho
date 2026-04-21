package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.ItemType;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public record ItemResponse(
        UUID id,
        String sku,
        String barcode,
        String name,
        String description,
        ItemType itemType,
        String category,
        String brand,
        String manufacturer,
        String hsnCode,
        String unitOfMeasure,
        BigDecimal purchasePrice,
        BigDecimal salePrice,
        BigDecimal mrp,
        BigDecimal gstRate,
        UUID defaultTaxGroupId,
        boolean trackInventory,
        boolean trackBatches,
        BigDecimal reorderLevel,
        BigDecimal reorderQuantity,
        UUID preferredVendorId,
        String preferredVendorName,
        BigDecimal weight,
        String weightUnit,
        BigDecimal length,
        BigDecimal width,
        BigDecimal height,
        String dimensionUnit,
        String drugSchedule,
        String composition,
        String dosageForm,
        String packSize,
        String storageCondition,
        boolean prescriptionRequired,
        boolean weightBasedBilling,
        String revenueAccountCode,
        String cogsAccountCode,
        String inventoryAccountCode,
        boolean active,
        BigDecimal totalOnHand,
        Instant createdAt,
        UUID groupId,
        Map<String, String> variantAttributes,
        String groupName,
        String purchaseUom,
        BigDecimal purchaseUomConversion,
        BigDecimal purchasePricePerUom,
        List<UnitPriceInfo> secondaryUnits
) {
    public record UnitPriceInfo(
            UUID uomId,
            String uomAbbreviation,
            String uomName,
            BigDecimal conversionFactor,
            BigDecimal customPrice
    ) {}
}
