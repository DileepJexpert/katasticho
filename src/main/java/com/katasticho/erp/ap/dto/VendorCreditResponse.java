package com.katasticho.erp.ap.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record VendorCreditResponse(
        UUID id,
        UUID contactId,
        String vendorName,
        String creditNumber,
        LocalDate creditDate,
        UUID purchaseBillId,
        String reason,
        String status,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        BigDecimal balance,
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
            UUID itemId,
            UUID accountId,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal taxableAmount,
            BigDecimal gstRate,
            BigDecimal taxAmount,
            BigDecimal lineTotal
    ) {}
}
