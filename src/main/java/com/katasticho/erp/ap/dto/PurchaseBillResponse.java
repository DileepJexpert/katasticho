package com.katasticho.erp.ap.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PurchaseBillResponse(
        UUID id,
        UUID contactId,
        String vendorName,
        String billNumber,
        String vendorBillNumber,
        LocalDate billDate,
        LocalDate dueDate,
        String status,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        BigDecimal amountPaid,
        BigDecimal balanceDue,
        BigDecimal tdsAmount,
        String currency,
        String placeOfSupply,
        boolean reverseCharge,
        UUID journalEntryId,
        String notes,
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
            BigDecimal discountPercent,
            BigDecimal discountAmount,
            BigDecimal taxableAmount,
            BigDecimal gstRate,
            BigDecimal taxAmount,
            BigDecimal lineTotal
    ) {}
}
