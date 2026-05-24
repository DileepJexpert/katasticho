package com.katasticho.erp.procurement.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record DebitNoteLineResponse(
        UUID id,
        UUID itemId,
        String description,
        UUID batchId,
        String batchNumber,
        LocalDate expiryDate,
        BigDecimal quantity,
        BigDecimal unitPrice,
        UUID taxGroupId,
        String hsnCode,
        BigDecimal taxRate,
        BigDecimal taxAmount,
        BigDecimal lineTotal
) {}
