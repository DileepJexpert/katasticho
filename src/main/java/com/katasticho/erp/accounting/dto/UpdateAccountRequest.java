package com.katasticho.erp.accounting.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record UpdateAccountRequest(
        @NotBlank(message = "Account name is required")
        @Size(max = 255)
        String name,

        String subType,
        String description,
        BigDecimal openingBalance
) {}
