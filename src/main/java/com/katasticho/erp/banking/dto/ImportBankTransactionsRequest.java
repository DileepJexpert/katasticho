package com.katasticho.erp.banking.dto;

import jakarta.validation.constraints.NotBlank;

public record ImportBankTransactionsRequest(
        @NotBlank(message = "CSV text is required")
        String csvText
) {
}
