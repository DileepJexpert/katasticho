package com.katasticho.erp.pricing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record SchemeRequest(
    @NotBlank String name,
    @NotNull String schemeType,
    UUID itemId,
    BigDecimal buyQuantity,
    BigDecimal freeQuantity,
    BigDecimal discountPercent,
    BigDecimal minOrderQuantity,
    LocalDate validFrom,
    LocalDate validTo,
    UUID supplierId,
    boolean active
) {}
