package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record GenericSubstitutionResponse(
        UUID id,
        UUID drugMasterId,
        UUID substituteDrugMasterId,
        String substituteBrandName,
        String substituteComposition,
        String manufacturer,
        BigDecimal mrp,
        BigDecimal estimatedSavings,
        String reason
) {}
