package com.katasticho.erp.banking.dto;

import com.katasticho.erp.banking.entity.PaymentMatch;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PaymentMatchResponse(
        UUID id,
        UUID invoiceId,
        String invoiceNumber,
        UUID contactId,
        String contactName,
        BigDecimal matchedAmount,
        BigDecimal confidence,
        String matchStatus,
        UUID paymentId,
        Instant acceptedAt
) {
    public static PaymentMatchResponse from(
            PaymentMatch match,
            String invoiceNumber,
            String contactName
    ) {
        return new PaymentMatchResponse(
                match.getId(),
                match.getInvoiceId(),
                invoiceNumber,
                match.getContactId(),
                contactName,
                match.getMatchedAmount(),
                match.getConfidence(),
                match.getMatchStatus(),
                match.getPaymentId(),
                match.getAcceptedAt()
        );
    }
}
