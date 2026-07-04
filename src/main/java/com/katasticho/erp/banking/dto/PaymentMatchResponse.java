package com.katasticho.erp.banking.dto;

import com.katasticho.erp.banking.entity.PaymentMatch;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PaymentMatchResponse(
        UUID id,
        String matchType,        // INVOICE (money in), BILL (money out), or ACCOUNT (bank-rule categorisation)
        UUID invoiceId,
        UUID billId,
        /** Invoice number, vendor bill number, or (ACCOUNT) the target GL code. */
        String documentNumber,
        /** Kept for older clients — same as documentNumber for invoice matches. */
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
            String documentNumber,
            String contactName
    ) {
        // Mirror documentNumber into the legacy invoiceNumber field only for real
        // invoice matches (BILL and ACCOUNT have no invoice).
        boolean isInvoice = match.getInvoiceId() != null;
        return new PaymentMatchResponse(
                match.getId(),
                match.getMatchType(),
                match.getInvoiceId(),
                match.getBillId(),
                documentNumber,
                isInvoice ? documentNumber : null,
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
