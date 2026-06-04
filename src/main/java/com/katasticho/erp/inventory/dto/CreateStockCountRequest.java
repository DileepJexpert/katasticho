package com.katasticho.erp.inventory.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateStockCountRequest(
        @NotNull UUID warehouseId,
        LocalDate countDate,
        String notes,
        @NotNull List<StockCountLineRequest> lines
) {}
