package com.katasticho.erp.payment.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "payout_disbursement")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PayoutDisbursement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(nullable = false, length = 50)
    @Builder.Default
    private String provider = "RAZORPAYX";

    @Column(name = "provider_payout_id", length = 100)
    private String providerPayoutId;

    @Column(length = 100)
    private String utr;

    @Column(nullable = false, length = 50)
    @Builder.Default
    private String status = "INITIATED"; // INITIATED, PROCESSING, PROCESSED, ACCOUNTING_FAILED, REVERSED, FAILED

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(nullable = false, precision = 14, scale = 4)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "payout_mode", nullable = false, length = 20)
    @Builder.Default
    private String payoutMode = "IMPS"; // IMPS, NEFT, RTGS, UPI

    @Column(name = "beneficiary_name", length = 255)
    private String beneficiaryName;

    @Column(name = "account_number", length = 100)
    private String accountNumber;

    @Column(name = "ifsc_code", length = 50)
    private String ifscCode;

    @Column(length = 255)
    private String vpa;

    @Column(name = "vendor_payment_id")
    private UUID vendorPaymentId;

    @Column(name = "failure_reason", columnDefinition = "TEXT")
    private String failureReason;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
