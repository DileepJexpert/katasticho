package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreditNoteResponse(
        UUID id,
        UUID customerId,
        String customerName,
        UUID invoiceId,
        String invoiceNumber,
        String creditNoteNumber,
        LocalDate creditNoteDate,
        String reason,
        String status,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        String currency,
        String placeOfSupply,
        UUID journalEntryId,
        List<LineResponse> lines,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            int lineNumber,
            String description,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal taxableAmount,
            BigDecimal gstRate,
            BigDecimal taxAmount,
            BigDecimal lineTotal,
            String accountCode
    ) {}
}
