package com.katasticho.erp.pharma.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record CustomerIndentRequest(
        UUID contactId,
        @NotBlank String customerName,
        String customerPhone,
        @NotNull UUID itemId,
        @NotNull @DecimalMin("0.0001") BigDecimal quantity,
        String source,
        LocalDate neededBy,
        String notes
) {}
