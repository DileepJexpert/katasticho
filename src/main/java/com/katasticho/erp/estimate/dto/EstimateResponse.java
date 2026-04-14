package com.katasticho.erp.estimate.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record EstimateResponse(
        UUID id,
        String estimateNumber,
        UUID contactId,
        String contactName,
        LocalDate estimateDate,
        LocalDate expiryDate,
        String status,
        BigDecimal subtotal,
        BigDecimal discountAmount,
        BigDecimal taxAmount,
        BigDecimal total,
        String currency,
        String referenceNumber,
        String subject,
        String notes,
        String terms,
        UUID convertedToInvoiceId,
        Instant convertedAt,
        Instant sentAt,
        Instant acceptedAt,
        Instant declinedAt,
        List<LineResponse> lines,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            int lineNumber,
            UUID itemId,
            String description,
            String unit,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal rate,
            BigDecimal discountPct,
            BigDecimal taxRate,
            BigDecimal amount
    ) {}
}
