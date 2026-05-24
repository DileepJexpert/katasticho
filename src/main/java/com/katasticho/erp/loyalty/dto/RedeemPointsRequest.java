package com.katasticho.erp.loyalty.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record RedeemPointsRequest(
        @NotNull UUID contactId,
        @NotNull BigDecimal redeemAmount,
        @NotNull UUID receiptId
) {}
