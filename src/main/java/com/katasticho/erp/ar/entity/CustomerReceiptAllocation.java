package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Junction row: one customer receipt can be split across multiple invoices,
 * and one invoice can receive allocations from multiple receipts.
 * UNIQUE(customer_receipt_id, invoice_id) in the DB prevents double-application
 * of the same receipt to the same invoice. The AR mirror of
 * {@code com.katasticho.erp.ap.entity.VendorPaymentAllocation}.
 */
@Entity
@Table(name = "customer_receipt_allocation")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CustomerReceiptAllocation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_receipt_id", nullable = false)
    private CustomerReceipt customerReceipt;

    @Column(name = "invoice_id", nullable = false)
    private UUID invoiceId;

    @Column(name = "amount_applied", nullable = false)
    private BigDecimal amountApplied;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
