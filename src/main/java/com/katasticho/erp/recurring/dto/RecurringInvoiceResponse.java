package com.katasticho.erp.recurring.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record RecurringInvoiceResponse(
        UUID id,
        String profileName,
        UUID contactId,
        String contactName,
        String frequency,
        LocalDate startDate,
        LocalDate endDate,
        LocalDate nextInvoiceDate,
        int paymentTermsDays,
        boolean autoSend,
        String status,
        String currency,
        String notes,
        String terms,
        int totalGenerated,
        Instant lastGeneratedAt,
        BigDecimal templateTotal,
        List<LineResponse> lineItems,
        Instant createdAt
) {
    public record LineResponse(
            UUID itemId,
            String description,
            String unit,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal rate,
            BigDecimal discountPct,
            BigDecimal taxRate,
            String accountCode,
            BigDecimal amount
    ) {}
}
