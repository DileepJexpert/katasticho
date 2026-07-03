package com.katasticho.erp.payment.dto;

import com.katasticho.erp.payment.entity.PaymentLink;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** A payment link as surfaced to the UI (no secrets). */
public record PaymentLinkResponse(
        UUID id,
        UUID invoiceId,
        String provider,
        String providerLinkId,
        String referenceId,
        String shortUrl,
        BigDecimal amount,
        String currency,
        String status,
        String providerPaymentId,
        UUID recordedPaymentId,
        Instant paidAt,
        Instant createdAt
) {
    public static PaymentLinkResponse of(PaymentLink l) {
        return new PaymentLinkResponse(l.getId(), l.getInvoiceId(), l.getProvider(),
                l.getProviderLinkId(), l.getReferenceId(), l.getShortUrl(), l.getAmount(),
                l.getCurrency(), l.getStatus(), l.getProviderPaymentId(),
                l.getRecordedPaymentId(), l.getPaidAt(), l.getCreatedAt());
    }
}
