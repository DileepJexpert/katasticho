package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record ExpiringSoonResponse(
        UUID itemId,
        String itemName,
        String sku,
        String batchNumber,
        LocalDate expiryDate,
        long daysLeft,
        BigDecimal quantityOnHand
) {}
