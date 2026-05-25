package com.katasticho.erp.indent.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record IndentResponse(
        UUID id,
        UUID contactId,
        String contactName,
        String contactPhone,
        UUID itemId,
        String itemName,
        String sku,
        BigDecimal requestedQty,
        String unit,
        String notes,
        String status,
        UUID purchaseOrderId,
        LocalDate promisedDate,
        UUID fulfilledReceiptId,
        Instant fulfilledAt,
        Instant createdAt,
        UUID createdBy
) {}
