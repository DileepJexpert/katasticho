package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CustomerReceiptResponse(
        UUID id,
        UUID contactId,
        String contactName,
        String receiptNumber,
        LocalDate receiptDate,
        BigDecimal amount,
        BigDecimal allocatedAmount,
        BigDecimal advanceAmount,
        String currency,
        String paymentMethod,
        String referenceNumber,
        String notes,
        UUID journalEntryId,
        List<AllocationResponse> allocations,
        Instant createdAt
) {
    public record AllocationResponse(
            UUID id,
            UUID invoiceId,
            String invoiceNumber,
            BigDecimal amountApplied
    ) {}
}
