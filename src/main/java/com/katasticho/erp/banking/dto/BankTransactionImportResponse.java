package com.katasticho.erp.banking.dto;

import java.util.List;

public record BankTransactionImportResponse(
        int imported,
        int skipped,
        List<BankTransactionResponse> transactions
) {
}
