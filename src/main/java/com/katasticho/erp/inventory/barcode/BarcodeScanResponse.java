package com.katasticho.erp.inventory.barcode;

import java.math.BigDecimal;
import java.util.UUID;

public record BarcodeScanResponse(
        GsOneCode parsed,
        DrugMasterRef drugMaster,
        ItemRef item
) {
    public record DrugMasterRef(
            UUID id,
            String brandName,
            String genericName,
            String hsnCode,
            BigDecimal gstRate,
            String manufacturer,
            String drugSchedule
    ) {}

    public record ItemRef(
            UUID id,
            String name,
            String sku,
            boolean trackBatches
    ) {}
}
