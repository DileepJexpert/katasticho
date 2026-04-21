package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.ItemType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

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

        @Size(max = 50) String barcode,
        @Size(max = 100) String manufacturer,
        UUID preferredVendorId,

        BigDecimal weight,
        @Size(max = 10) String weightUnit,
        BigDecimal length,
        BigDecimal width,
        BigDecimal height,
        @Size(max = 10) String dimensionUnit,

        // Pharmacy-specific (when organisation.industry = 'PHARMACY')
        @Size(max = 10) String drugSchedule,
        String composition,
        @Size(max = 50) String dosageForm,
        @Size(max = 50) String packSize,
        @Size(max = 100) String storageCondition,
        Boolean prescriptionRequired,
        Boolean weightBasedBilling,

        String revenueAccountCode,
        String cogsAccountCode,
        String inventoryAccountCode,

        /** Initial on-hand quantity. If &gt; 0, an OPENING movement is recorded. */
        @DecimalMin(value = "0.00", message = "Opening stock must be >= 0")
        BigDecimal openingStock,

        /** Optional warehouse for the opening movement. Defaults to org's default warehouse. */
        UUID openingWarehouseId,

        /** Batch number for opening stock when trackBatches=true. Required if openingStock > 0 and trackBatches=true. */
        @Size(max = 100)
        String openingBatchNumber,

        /** Manufacturing date for the opening batch. Optional. */
        LocalDate openingMfgDate,

        /** Expiry date for the opening batch. Optional. */
        LocalDate openingExpiryDate,

        /** Purchase UoM abbreviation when buying in a different unit (e.g. "BORA"). */
        @Size(max = 20)
        String purchaseUom,

        /** How many base units make up 1 purchase unit (e.g. 1 Bora = 50 KG → factor = 50). */
        @DecimalMin(value = "0.0001", message = "Conversion factor must be > 0")
        BigDecimal purchaseUomConversion,

        /** Price per purchase unit (e.g. ₹2750 per Bora). */
        @DecimalMin(value = "0.00")
        BigDecimal purchasePricePerUom,

        /** Additional selling/buying units with optional custom prices. */
        List<UnitPriceEntry> secondaryUnits,

        UUID groupId,

        Map<String, String> variantAttributes
) {
    public record UnitPriceEntry(
            @NotBlank String uomAbbreviation,
            @NotNull @DecimalMin(value = "0.0001") BigDecimal conversionFactor,
            @DecimalMin(value = "0.00") BigDecimal customPrice
    ) {}
}
