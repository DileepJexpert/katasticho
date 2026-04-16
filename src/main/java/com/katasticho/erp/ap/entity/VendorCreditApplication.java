package com.katasticho.erp.ap.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Records the application of a vendor credit against a purchase bill.
 * Reduces both the credit's {@code balance} and the bill's
 * {@code balanceDue}.
 */
@Entity
@Table(name = "vendor_credit_application")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VendorCreditApplication {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "vendor_credit_id", nullable = false)
    private UUID vendorCreditId;

    @Column(name = "purchase_bill_id", nullable = false)
    private UUID purchaseBillId;

    @Column(name = "amount_applied", nullable = false)
    private BigDecimal amountApplied;

    @Column(name = "applied_at", nullable = false)
    private Instant appliedAt;

    @Column(name = "applied_by")
    private UUID appliedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        if (this.appliedAt == null) {
            this.appliedAt = Instant.now();
        }
    }
}
