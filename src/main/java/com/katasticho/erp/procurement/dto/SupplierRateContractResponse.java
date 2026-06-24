package com.katasticho.erp.procurement.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record SupplierRateContractResponse(
        UUID id,
        UUID orgId,
        String contractNumber,
        UUID supplierContactId,
        String status,
        LocalDate validFrom,
        LocalDate validUntil,
        String currency,
        String notes,
        List<LineResponse> lines,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            UUID itemId,
            BigDecimal unitPrice,
            BigDecimal minOrderQty,
            String notes
    ) {}
}
