package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record PicklistLineRequest(
        @NotNull UUID salesOrderLineId,
        @NotNull BigDecimal requiredQuantity,
        UUID batchId,
        String notes
) {}
