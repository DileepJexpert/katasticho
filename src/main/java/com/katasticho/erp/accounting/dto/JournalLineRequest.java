package com.katasticho.erp.accounting.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;

public record JournalLineRequest(
        @NotBlank(message = "Account code is required")
        String accountCode,

        @DecimalMin(value = "0.00", message = "Debit must be >= 0")
        BigDecimal debit,

        @DecimalMin(value = "0.00", message = "Credit must be >= 0")
        BigDecimal credit,

        String description,
        String taxComponentCode,
        String costCentre
) {
    public JournalLineRequest {
        if (debit == null) debit = BigDecimal.ZERO;
        if (credit == null) credit = BigDecimal.ZERO;
    }
}
