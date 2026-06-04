package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

public record CreatePicklistRequest(
        @NotNull UUID salesOrderId,
        @NotNull UUID warehouseId,
        UUID assignedTo,
        String notes,
        @NotNull List<PicklistLineRequest> lines
) {}
