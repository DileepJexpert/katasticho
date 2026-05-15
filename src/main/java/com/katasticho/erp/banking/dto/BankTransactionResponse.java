package com.katasticho.erp.banking.dto;

import com.katasticho.erp.banking.entity.BankTransaction;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record BankTransactionResponse(
        UUID id,
        LocalDate transactionDate,
        BigDecimal amount,
        String direction,
        String narration,
        String utr,
        String payerName,
        String payerVpa,
        String status,
        UUID paymentId,
        List<PaymentMatchResponse> suggestedMatches,
        Instant createdAt
) {
    public static BankTransactionResponse from(
            BankTransaction transaction,
            List<PaymentMatchResponse> suggestedMatches
    ) {
        return new BankTransactionResponse(
                transaction.getId(),
                transaction.getTransactionDate(),
                transaction.getAmount(),
                transaction.getDirection(),
                transaction.getNarration(),
                transaction.getUtr(),
                transaction.getPayerName(),
                transaction.getPayerVpa(),
                transaction.getStatus(),
                transaction.getPaymentId(),
                suggestedMatches,
                transaction.getCreatedAt()
        );
    }
}
