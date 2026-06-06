package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record UpdatePicklistLineRequest(
        @NotNull List<PickedLineEntry> lines
) {
    public record PickedLineEntry(
            @NotNull UUID lineId,
            @NotNull BigDecimal pickedQuantity,
            UUID batchId,
            String notes
    ) {}
}
