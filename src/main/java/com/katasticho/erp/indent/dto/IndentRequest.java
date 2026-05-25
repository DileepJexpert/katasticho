package com.katasticho.erp.indent.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record IndentRequest(
        UUID contactId,
        String contactName,
        String contactPhone,
        UUID itemId,
        String itemName,
        String sku,
        BigDecimal requestedQty,
        String unit,
        String notes,
        LocalDate promisedDate
) {}
