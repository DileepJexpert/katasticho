package com.katasticho.erp.loyalty.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record EarnPointsRequest(
        @NotNull UUID contactId,
        @NotNull BigDecimal saleTotal,
        @NotNull UUID receiptId
) {}
