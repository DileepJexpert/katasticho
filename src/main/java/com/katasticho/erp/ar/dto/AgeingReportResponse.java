package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record AgeingReportResponse(
        BigDecimal totalOutstanding,
        BigDecimal current,
        BigDecimal days1to30,
        BigDecimal days31to60,
        BigDecimal days61to90,
        BigDecimal days90plus,
        List<ContactAgeing> contacts
) {
    public record ContactAgeing(
            UUID contactId,
            String contactName,
            BigDecimal totalOutstanding,
            BigDecimal current,
            BigDecimal days1to30,
            BigDecimal days31to60,
            BigDecimal days61to90,
            BigDecimal days90plus,
            List<InvoiceAgeing> invoices
    ) {}

    public record InvoiceAgeing(
            UUID invoiceId,
            String invoiceNumber,
            BigDecimal balanceDue,
            long daysOverdue,
            String bucket
    ) {}
}
