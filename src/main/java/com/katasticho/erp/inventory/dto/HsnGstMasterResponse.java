package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record HsnGstMasterResponse(
        UUID id,
        String hsnCode,
        String description,
        String category,
        BigDecimal gstRate
) {}
