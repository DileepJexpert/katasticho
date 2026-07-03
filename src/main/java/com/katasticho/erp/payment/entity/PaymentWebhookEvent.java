package com.katasticho.erp.payment.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Append-only dedupe log of inbound gateway webhook events. A duplicate
 * (provider, event_id) — Razorpay retries and can fire overlapping events for
 * the same money — is rejected by the unique index, so an invoice is never
 * settled twice.
 */
@Entity
@Table(name = "payment_webhook_event")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentWebhookEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id")
    private UUID orgId;

    @Column(nullable = false)
    private String provider;

    @Column(name = "event_id", nullable = false)
    private String eventId;

    @Column(name = "event_type")
    private String eventType;

    @Column(name = "payment_link_id")
    private UUID paymentLinkId;

    @Column(name = "signature_valid", nullable = false)
    private boolean signatureValid;

    @Column(nullable = false)
    private boolean processed;

    @Column(name = "received_at", nullable = false, updatable = false,
            insertable = false, columnDefinition = "TIMESTAMPTZ DEFAULT NOW()")
    private Instant receivedAt;
}
