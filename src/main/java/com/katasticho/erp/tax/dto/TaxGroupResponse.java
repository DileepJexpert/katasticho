package com.katasticho.erp.tax.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record TaxGroupResponse(
        UUID id,
        String name,
        String description,
        boolean active,
        List<TaxRateInfo> rates
) {
    public record TaxRateInfo(
            UUID id,
            String rateCode,
            String name,
            BigDecimal percentage,
            String taxType,
            boolean recoverable
    ) {}
}
