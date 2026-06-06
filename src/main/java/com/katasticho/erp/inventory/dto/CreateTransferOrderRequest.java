package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateTransferOrderRequest(
        @NotNull UUID fromWarehouseId,
        @NotNull UUID toWarehouseId,
        LocalDate transferDate,
        String notes,
        @NotNull List<TransferOrderLineRequest> lines
) {}
