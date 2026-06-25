package com.katasticho.erp.banking.dto;

import com.katasticho.erp.banking.entity.BankAccount;

import java.math.BigDecimal;
import java.util.UUID;

public record BankAccountResponse(
        UUID id,
        String name,
        String bankName,
        String accountNumber,
        String ifsc,
        String branch,
        String accountType,
        UUID glAccountId,
        String glAccountCode,
        BigDecimal openingBalance,
        boolean isDefault,
        boolean isActive,
        String notes
) {
    public static BankAccountResponse from(BankAccount b) {
        return new BankAccountResponse(
                b.getId(), b.getName(), b.getBankName(), b.getAccountNumber(),
                b.getIfsc(), b.getBranch(), b.getAccountType(),
                b.getGlAccountId(), b.getGlAccountCode(),
                b.getOpeningBalance(), b.isDefault(), b.isActive(), b.getNotes());
    }
}
