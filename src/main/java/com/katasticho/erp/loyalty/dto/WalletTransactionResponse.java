package com.katasticho.erp.loyalty.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record WalletTransactionResponse(
        UUID id,
        String txnType,
        BigDecimal amount,
        BigDecimal balanceAfter,
        String referenceType,
        String notes,
        Instant createdAt
) {}
