package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record DrugMasterResponse(
        UUID id,
        String brandName,
        String genericName,
        String saltComposition,
        String manufacturer,
        String hsnCode,
        BigDecimal gstRate,
        String drugSchedule,
        String dosageForm,
        String packSize,
        BigDecimal mrp,
        boolean prescriptionRequired
) {}
