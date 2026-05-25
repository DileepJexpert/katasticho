package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.DrugMaster;

import java.math.BigDecimal;
import java.util.UUID;

public record DrugMasterResponse(
        UUID id,
        String brandName,
        String genericName,
        UUID saltId,
        String saltName,
        String saltComposition,
        String manufacturer,
        String hsnCode,
        BigDecimal gstRate,
        String drugSchedule,
        String dosageForm,
        String packSize,
        BigDecimal mrp,
        boolean prescriptionRequired
) {
    public static DrugMasterResponse from(DrugMaster d) {
        return new DrugMasterResponse(
                d.getId(),
                d.getBrandName(),
                d.getGenericName(),
                d.getSalt() != null ? d.getSalt().getId() : null,
                d.getSalt() != null ? d.getSalt().getName() : null,
                d.getSaltComposition(),
                d.getManufacturer(),
                d.getHsnCode(),
                d.getGstRate(),
                d.getDrugSchedule(),
                d.getDosageForm(),
                d.getPackSize(),
                d.getMrp(),
                d.isPrescriptionRequired()
        );
    }
}
