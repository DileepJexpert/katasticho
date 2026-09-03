package com.katasticho.erp.kenya.dto;

import com.katasticho.erp.kenya.entity.MpesaTransaction;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Builder
public record MpesaTransactionResponse(
        UUID id,
        UUID orgId,
        String mpesaReceiptNumber,
        String transactionType,
        String phoneNumber,
        BigDecimal amount,
        String partyName,
        String accountReference,
        String status,
        UUID matchedInvoiceId,
        UUID matchedJournalEntryId,
        Instant transactionTime,
        Instant createdAt
) {
    public static MpesaTransactionResponse from(MpesaTransaction t) {
        return new MpesaTransactionResponse(
                t.getId(),
                t.getOrgId(),
                t.getMpesaReceiptNumber(),
                t.getTransactionType(),
                t.getPhoneNumber(),
                t.getAmount(),
                t.getPartyName(),
                t.getAccountReference(),
                t.getStatus(),
                t.getMatchedInvoiceId(),
                t.getMatchedJournalEntryId(),
                t.getTransactionTime(),
                t.getCreatedAt()
        );
    }
}