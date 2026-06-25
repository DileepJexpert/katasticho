package com.katasticho.erp.banking.dto;

import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Create / update a bank account. {@code glAccountCode} is optional: when blank
 * the service auto-creates a dedicated GL sub-account under Bank (1020); when
 * supplied it links to that existing GL account instead.
 */
public record BankAccountRequest(
        @NotBlank String name,
        String bankName,
        String accountNumber,
        String ifsc,
        String branch,
        String accountType,
        String glAccountCode,
        BigDecimal openingBalance,
        Boolean isDefault,
        Boolean isActive,
        String notes,
        UUID branchId
) {}
