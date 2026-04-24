package com.katasticho.erp.ai.dto;

import java.math.BigDecimal;
import java.util.List;

public record ItemScanResponse(
        List<ScannedItem> items,
        double confidence,
        String source
) {
    public record ScannedItem(
            String name,
            String barcode,
            String hsnCode,
            String category,
            String brand,
            String manufacturer,
            String unitOfMeasure,
            BigDecimal mrp,
            BigDecimal salePrice,
            BigDecimal purchasePrice,
            BigDecimal gstRate,
            String description,
            String genericName,
            String composition,
            String dosageForm,
            String drugSchedule,
            String packSize,
            BigDecimal weight,
            String weightUnit,
            BigDecimal reorderLevel
    ) {}
}
