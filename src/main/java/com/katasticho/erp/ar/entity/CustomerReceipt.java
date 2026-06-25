package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Inbound lump-sum collection from a customer. Unlike AR's legacy one-to-one
 * {@link Payment}→invoice link, a customer receipt can be allocated across
 * multiple invoices via {@link CustomerReceiptAllocation}, and any unallocated
 * excess is parked as a Customer Advance (CoA 2100) liability
 * ({@code advanceAmount}). This is the AR mirror of
 * {@code com.katasticho.erp.ap.entity.VendorPayment}.
 */
@Entity
@Table(name = "customer_receipt")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CustomerReceipt {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "receipt_number", nullable = false, length = 30)
    private String receiptNumber;

    @Column(name = "receipt_date", nullable = false)
    private LocalDate receiptDate;

    /** Total cash/bank received in transaction currency. */
    @Column(nullable = false)
    private BigDecimal amount;

    /** Σ of allocation amounts applied to invoices. */
    @Column(name = "allocated_amount", nullable = false)
    @Builder.Default
    private BigDecimal allocatedAmount = BigDecimal.ZERO;

    /** amount − allocatedAmount; parked as a Customer Advance liability. */
    @Column(name = "advance_amount", nullable = false)
    @Builder.Default
    private BigDecimal advanceAmount = BigDecimal.ZERO;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "exchange_rate", nullable = false)
    @Builder.Default
    private BigDecimal exchangeRate = BigDecimal.ONE;

    @Column(name = "base_amount", nullable = false)
    private BigDecimal baseAmount;

    @Column(name = "payment_method", nullable = false, length = 30)
    private String paymentMethod;

    @Column(name = "reference_number", length = 100)
    private String referenceNumber;

    private String notes;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    // ── Allocations ──────────────────────────────────────────

    @OneToMany(mappedBy = "customerReceipt", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<CustomerReceiptAllocation> allocations = new ArrayList<>();

    public void addAllocation(CustomerReceiptAllocation alloc) {
        allocations.add(alloc);
        alloc.setCustomerReceipt(this);
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
