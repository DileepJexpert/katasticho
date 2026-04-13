package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.AttributeDefinition;
import com.katasticho.erp.inventory.entity.ItemGroup;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ItemGroupResponse(
        UUID id,
        String name,
        String description,
        String skuPrefix,
        String hsnCode,
        BigDecimal gstRate,
        String defaultUom,
        BigDecimal defaultPurchasePrice,
        BigDecimal defaultSalePrice,
        List<AttributeDefinition> attributeDefinitions,
        int variantCount,
        Instant createdAt
) {
    public static ItemGroupResponse from(ItemGroup g, int variantCount) {
        return new ItemGroupResponse(
                g.getId(),
                g.getName(),
                g.getDescription(),
                g.getSkuPrefix(),
                g.getHsnCode(),
                g.getGstRate(),
                g.getDefaultUom(),
                g.getDefaultPurchasePrice(),
                g.getDefaultSalePrice(),
                g.getAttributeDefinitions(),
                variantCount,
                g.getCreatedAt()
        );
    }
}
