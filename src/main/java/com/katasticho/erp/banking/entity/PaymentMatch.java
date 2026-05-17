package com.katasticho.erp.banking.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "payment_match")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentMatch {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "bank_transaction_id", nullable = false)
    private UUID bankTransactionId;

    @Column(name = "invoice_id")
    private UUID invoiceId;

    @Column(name = "contact_id")
    private UUID contactId;

    @Column(name = "matched_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal matchedAmount;

    @Column(nullable = false, precision = 5, scale = 4)
    private BigDecimal confidence;

    @Column(name = "match_status", nullable = false, length = 30)
    @Builder.Default
    private String matchStatus = "SUGGESTED";

    @Column(name = "payment_id")
    private UUID paymentId;

    @Column(name = "accepted_by")
    private UUID acceptedBy;

    @Column(name = "accepted_at")
    private Instant acceptedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }
}
