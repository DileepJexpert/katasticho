package com.katasticho.erp.payment.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A hosted payment-gateway link for an invoice's outstanding balance. The
 * webhook (which carries no JWT) resolves the invoice + org solely from this
 * row, so it is the single source of truth for a link's lifecycle.
 */
@Entity
@Table(name = "payment_link")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentLink extends BaseEntity {

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(nullable = false)
    private String provider;

    @Column(name = "provider_link_id")
    private String providerLinkId;

    @Column(name = "reference_id", nullable = false)
    private String referenceId;

    @Column(name = "short_url")
    private String shortUrl;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(nullable = false)
    private String currency;

    @Column(nullable = false)
    private String status;

    @Column(name = "provider_payment_id")
    private String providerPaymentId;

    @Column(name = "recorded_payment_id")
    private UUID recordedPaymentId;

    @Column(name = "paid_at")
    private Instant paidAt;

    @Column(name = "last_event_id")
    private String lastEventId;

    @Column
    private String notes;
}
