package com.katasticho.erp.sales.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateDeliveryChallanRequest(
        @NotNull(message = "Sales Order ID is required")
        UUID salesOrderId,

        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<ChallanLineRequest> lines,

        LocalDate challanDate,
        String deliveryMethod,
        String vehicleNumber,
        String trackingNumber,
        String notes,
        String shippingAddress
) {
    public record ChallanLineRequest(
            @NotNull(message = "SO line ID is required")
            UUID soLineId,

            @NotNull(message = "Quantity is required")
            @DecimalMin(value = "0.001", message = "Quantity must be positive")
            BigDecimal quantity,

            UUID batchId
    ) {}
}
