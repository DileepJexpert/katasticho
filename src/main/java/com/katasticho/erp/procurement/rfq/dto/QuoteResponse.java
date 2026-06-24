package com.katasticho.erp.procurement.rfq.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record QuoteResponse(
        UUID id,
        UUID rfqId,
        UUID supplierContactId,
        String quoteNumber,
        LocalDate validUntil,
        BigDecimal totalAmount,
        String currency,
        String status,
        String notes,
        List<LineResponse> lines,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            UUID itemId,
            String description,
            BigDecimal quantity,
            BigDecimal unitPrice,
            Integer leadTimeDays,
            String notes
    ) {}
}
