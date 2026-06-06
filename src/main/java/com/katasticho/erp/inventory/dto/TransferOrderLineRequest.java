package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

public record TransferOrderLineRequest(
        @NotNull UUID itemId,
        UUID batchId,
        @NotNull BigDecimal quantity,
        String notes
) {}
