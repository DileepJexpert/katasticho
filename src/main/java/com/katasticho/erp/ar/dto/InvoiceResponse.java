package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record InvoiceResponse(
        UUID id,
        UUID contactId,
        String contactName,
        String invoiceNumber,
        LocalDate invoiceDate,
        LocalDate dueDate,
        String status,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        BigDecimal amountPaid,
        BigDecimal balanceDue,
        String currency,
        String placeOfSupply,
        boolean reverseCharge,
        UUID journalEntryId,
        String notes,
        List<LineResponse> lines,
        List<TaxLineResponse> taxLines,
        Instant createdAt
) {
    public record LineResponse(
            UUID id,
            int lineNumber,
            String description,
            String hsnCode,
            BigDecimal quantity,
            BigDecimal unitPrice,
            BigDecimal discountPercent,
            BigDecimal discountAmount,
            BigDecimal taxableAmount,
            BigDecimal gstRate,
            BigDecimal taxAmount,
            BigDecimal lineTotal,
            String accountCode,
            BigDecimal itemMrp,
            String batchNumber,
            String batchExpiry
    ) {}

    public record TaxLineResponse(
            String componentCode,
            BigDecimal rate,
            BigDecimal taxableAmount,
            BigDecimal taxAmount,
            String accountCode
    ) {}
}
