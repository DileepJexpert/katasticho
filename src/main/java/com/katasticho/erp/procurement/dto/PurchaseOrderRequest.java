package com.katasticho.erp.procurement.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PurchaseOrderRequest(
        @NotNull UUID supplierId,
        @NotNull LocalDate orderDate,
        LocalDate expectedDeliveryDate,
        String notes,
        UUID warehouseId,
        @NotEmpty @Valid List<LineRequest> lines
) {
    public record LineRequest(
            @NotNull UUID itemId,
            String description,
            @NotNull BigDecimal quantity,
            @NotNull BigDecimal unitPrice,
            UUID taxGroupId
    ) {}
}
