package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.AttributeDefinition;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;

/**
 * Create / update payload for {@link com.katasticho.erp.inventory.entity.ItemGroup}.
 *
 * <p>{@code attributeDefinitions} is the closed list of variant
 * attributes the group will accept. Empty list is legal at create
 * time (operator can fill it in later) but the bulk-generate endpoint
 * refuses to mint variants until the group has at least one
 * attribute defined.
 */
public record ItemGroupRequest(
        @NotBlank(message = "Group name is required")
        @Size(max = 255)
        String name,

        String description,

        @Size(max = 50, message = "SKU prefix must be at most 50 characters")
        String skuPrefix,

        @Size(max = 10)
        String hsnCode,

        @DecimalMin(value = "0.00", message = "GST rate must be >= 0")
        BigDecimal gstRate,

        @Size(max = 20)
        String defaultUom,

        @DecimalMin(value = "0.00", message = "Default purchase price must be >= 0")
        BigDecimal defaultPurchasePrice,

        @DecimalMin(value = "0.00", message = "Default sale price must be >= 0")
        BigDecimal defaultSalePrice,

        List<AttributeDefinition> attributeDefinitions
) {}
