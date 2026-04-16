package com.katasticho.erp.ap.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record VendorPaymentResponse(
        UUID id,
        UUID contactId,
        String vendorName,
        String paymentNumber,
        LocalDate paymentDate,
        BigDecimal amount,
        String currency,
        String paymentMode,
        UUID paidThroughId,
        String referenceNumber,
        BigDecimal tdsAmount,
        String notes,
        UUID journalEntryId,
        List<AllocationResponse> allocations,
        Instant createdAt
) {
    public record AllocationResponse(
            UUID id,
            UUID billId,
            String billNumber,
            BigDecimal amountApplied
    ) {}
}
