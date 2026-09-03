package com.katasticho.erp.kenya.dto;

import com.katasticho.erp.kenya.entity.KraEtimsInvoice;
import lombok.Builder;

import java.time.Instant;
import java.util.UUID;

@Builder
public record KraEtimsInvoiceResponse(
        UUID id,
        UUID orgId,
        UUID invoiceId,
        String controlUnitNumber,
        String scuReceiptNumber,
        String qrCodeUrl,
        String status,
        String responsePayload,
        Instant submittedAt,
        Instant createdAt
) {
    public static KraEtimsInvoiceResponse from(KraEtimsInvoice e) {
        return new KraEtimsInvoiceResponse(
                e.getId(),
                e.getOrgId(),
                e.getInvoiceId(),
                e.getControlUnitNumber(),
                e.getScuReceiptNumber(),
                e.getQrCodeUrl(),
                e.getStatus(),
                e.getResponsePayload(),
                e.getSubmittedAt(),
                e.getCreatedAt()
        );
    }
}