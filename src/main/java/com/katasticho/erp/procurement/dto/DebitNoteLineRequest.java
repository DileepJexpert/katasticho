package com.katasticho.erp.procurement.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record DebitNoteLineRequest(
        @NotNull UUID itemId,
        String description,
        UUID batchId,
        String batchNumber,
        LocalDate expiryDate,
        @NotNull BigDecimal quantity,
        @NotNull BigDecimal unitPrice,
        UUID taxGroupId,
        String hsnCode,
        BigDecimal taxRate
) {}
