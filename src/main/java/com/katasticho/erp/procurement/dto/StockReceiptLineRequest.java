package com.katasticho.erp.procurement.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record StockReceiptLineRequest(
        @NotNull UUID itemId,
        String description,
        String hsnCode,
        @NotNull @Positive BigDecimal quantity,
        String unitOfMeasure,
        @NotNull @PositiveOrZero BigDecimal unitPrice,
        BigDecimal discountPercent,
        BigDecimal gstRate,
        // Optional batch metadata for pharmacies / perishables
        String batchNumber,
        LocalDate expiryDate,
        LocalDate manufacturingDate
) {}
