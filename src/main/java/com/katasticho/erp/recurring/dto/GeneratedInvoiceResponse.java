package com.katasticho.erp.recurring.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Row in the "generated invoices" panel on the detail screen.
 * Joins {@code recurring_invoice_generation} to {@code invoice} so
 * the UI can render without a second request-per-row.
 */
public record GeneratedInvoiceResponse(
        UUID invoiceId,
        String invoiceNumber,
        LocalDate invoiceDate,
        BigDecimal total,
        String status,
        boolean autoSent,
        Instant generatedAt
) {}
