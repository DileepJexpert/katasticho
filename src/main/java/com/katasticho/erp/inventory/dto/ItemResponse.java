package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.ItemType;

import java.math.BigDecimal;
import java.time.Instant;
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
        String revenueAccountCode,
        String cogsAccountCode,
        String inventoryAccountCode,
        boolean active,
        BigDecimal totalOnHand,
        Instant createdAt,
        /** Optional FK to {@code item_group} — present only when this
         * item is a variant of a group. The Flutter picker uses it to
         * collapse siblings under their parent. */
        UUID groupId,
        /** Variant attributes when {@link #groupId} is non-null,
         * otherwise empty. */
        Map<String, String> variantAttributes,
        /** Group display name resolved at response-build time so the
         * Flutter picker doesn't need an N+1 fetch. NULL when
         * {@link #groupId} is NULL. */
        String groupName
) {}
