package com.katasticho.erp.sales.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record ConvertToInvoiceRequest(
        @NotEmpty(message = "At least one line item is required")
        @Valid
        List<InvoiceLineItem> lines
) {
    public record InvoiceLineItem(
            @NotNull(message = "Sales order line ID is required")
            UUID soLineId,

            @NotNull(message = "Quantity is required")
            @DecimalMin(value = "0.001", message = "Quantity must be positive")
            BigDecimal quantity
    ) {}
}
