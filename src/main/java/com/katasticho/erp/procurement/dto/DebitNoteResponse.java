package com.katasticho.erp.procurement.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record DebitNoteResponse(
        UUID id,
        UUID supplierId,
        String supplierName,
        String debitNoteNumber,
        String status,
        LocalDate noteDate,
        String returnReason,
        UUID referenceBillId,
        String notes,
        BigDecimal subtotal,
        BigDecimal taxAmount,
        BigDecimal totalAmount,
        List<DebitNoteLineResponse> lines,
        Instant createdAt
) {}
