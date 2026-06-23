package com.katasticho.erp.inventory.barcode;

import java.math.BigDecimal;
import java.util.UUID;

public record BarcodeScanResponse(
        GsOneCode parsed,
        DrugMasterRef drugMaster,
        ItemRef item,
        String rawCode,
        String parseError
) {
    public static BarcodeScanResponse gs1(GsOneCode parsed, DrugMasterRef dm, ItemRef item) {
        return new BarcodeScanResponse(parsed, dm, item, null, null);
    }

    public static BarcodeScanResponse unrecognised(String raw, String reason) {
        return new BarcodeScanResponse(null, null, null, raw, reason);
    }

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
