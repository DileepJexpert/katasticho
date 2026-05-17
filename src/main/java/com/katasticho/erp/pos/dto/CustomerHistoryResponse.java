package com.katasticho.erp.pos.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CustomerHistoryResponse(
        UUID contactId,
        String contactName,
        String phone,
        BigDecimal outstandingAmount,
        BigDecimal totalSpent,
        int visitCount,
        int periodDays,
        List<ReceiptSummary> recentReceipts
) {
    public record ReceiptSummary(
            UUID id,
            String receiptNumber,
            LocalDate receiptDate,
            BigDecimal total,
            String paymentMode,
            List<ItemSummary> items
    ) {}

    public record ItemSummary(
            String name,
            BigDecimal quantity,
            String unit,
            BigDecimal amount
    ) {}
}
