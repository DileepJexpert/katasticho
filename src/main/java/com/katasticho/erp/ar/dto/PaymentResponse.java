package com.katasticho.erp.ar.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record PaymentResponse(
        UUID id,
        UUID contactId,
        String contactName,
        UUID invoiceId,
        String invoiceNumber,
        String paymentNumber,
        LocalDate paymentDate,
        BigDecimal amount,
        String currency,
        String paymentMethod,
        String referenceNumber,
        String bankAccount,
        String notes,
        UUID journalEntryId,
        Instant createdAt
) {}
