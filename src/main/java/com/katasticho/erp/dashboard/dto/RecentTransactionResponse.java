package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record RecentTransactionResponse(
        UUID id,
        String type,
        String number,
        String customerName,
        BigDecimal amount,
        String paymentMode,
        Instant createdAt
) {}
