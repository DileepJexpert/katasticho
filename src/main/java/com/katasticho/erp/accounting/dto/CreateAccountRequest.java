package com.katasticho.erp.accounting.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record CreateAccountRequest(
        @NotBlank(message = "Account code is required")
        @Size(max = 20)
        String code,

        @NotBlank(message = "Account name is required")
        @Size(max = 255)
        String name,

        @NotBlank(message = "Account type is required")
        @Pattern(regexp = "^(ASSET|LIABILITY|EQUITY|REVENUE|EXPENSE)$", message = "Invalid account type")
        String type,

        String subType,
        String parentCode,
        String description,
        BigDecimal openingBalance
) {}
