package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record StockCountLineRequest(
        @NotNull UUID itemId,
        @NotNull BigDecimal countedQuantity,
        String notes
) {}
