package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record OverdueCustomerResponse(
        UUID contactId,
        String contactName,
        String phone,
        BigDecimal totalOutstanding,
        BigDecimal overdueAmount,
        LocalDate oldestDueDate,
        long maxDaysOverdue,
        int invoiceCount,
        Instant lastReminderSentAt,
        CollectionFollowUpResponse latestFollowUp,
        List<OverdueInvoice> invoices
) {
    public record OverdueInvoice(
            UUID invoiceId,
            String invoiceNumber,
            BigDecimal totalAmount,
            BigDecimal balanceDue,
            LocalDate dueDate,
            long daysOverdue
    ) {}
}
