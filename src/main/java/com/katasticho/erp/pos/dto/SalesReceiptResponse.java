package com.katasticho.erp.pos.dto;

import com.katasticho.erp.pos.entity.PaymentMode;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record SalesReceiptResponse(
        UUID id,
        String receiptNumber,
        LocalDate receiptDate,
        UUID branchId,
        UUID contactId,
        String contactName,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal total,
        PaymentMode paymentMode,
        BigDecimal amountReceived,
        BigDecimal changeReturned,
        String upiReference,
        String notes,
        UUID journalEntryId,
        Instant createdAt,
        List<LineResponse> lines
) {
    public record LineResponse(
            UUID id,
            int lineNumber,
            UUID itemId,
            String itemName,
            String itemSku,
            String description,
            BigDecimal quantity,
            String unit,
            BigDecimal rate,
            UUID taxGroupId,
            String hsnCode,
            BigDecimal amount,
            UUID batchId
    ) {}
}
