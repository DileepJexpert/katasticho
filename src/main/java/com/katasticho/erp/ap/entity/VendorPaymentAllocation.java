package com.katasticho.erp.ap.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Junction row: one vendor payment can be split across multiple
 * bills, and one bill can receive allocations from multiple payments.
 * UNIQUE(vendor_payment_id, purchase_bill_id) in the DB prevents
 * double-application.
 */
@Entity
@Table(name = "vendor_payment_allocation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VendorPaymentAllocation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vendor_payment_id", nullable = false)
    private VendorPayment vendorPayment;

    @Column(name = "purchase_bill_id", nullable = false)
    private UUID purchaseBillId;

    @Column(name = "amount_applied", nullable = false)
    private BigDecimal amountApplied;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
