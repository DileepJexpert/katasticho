package com.katasticho.erp.procurement.rfq.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record RfqResponse(
        UUID id,
        UUID orgId,
        String rfqNumber,
        String title,
        String status,
        LocalDate dueDate,
        String notes,
        List<LineResponse> lines,
        List<UUID> supplierContactIds,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            UUID itemId,
            String description,
            BigDecimal quantity,
            String hsnCode,
            BigDecimal gstRate
    ) {}
}
