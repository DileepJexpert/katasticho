package com.katasticho.erp.pharma.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record CustomerIndentResponse(
        UUID id,
        String indentNumber,
        UUID contactId,
        String customerName,
        String customerPhone,
        UUID itemId,
        String itemName,
        String itemSku,
        BigDecimal quantity,
        String status,
        String source,
        LocalDate neededBy,
        String notes,
        Instant notifiedAt,
        Instant fulfilledAt,
        Instant createdAt
) {}
