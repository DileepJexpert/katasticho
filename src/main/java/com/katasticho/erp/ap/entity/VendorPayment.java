package com.katasticho.erp.ap.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Outbound payment to a vendor. Unlike AR's one-to-one
 * payment→invoice link, a vendor payment can be allocated
 * across multiple purchase bills via {@link VendorPaymentAllocation}.
 */
@Entity
@Table(name = "vendor_payment")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VendorPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "payment_number", nullable = false, length = 30)
    private String paymentNumber;

    @Column(name = "payment_date", nullable = false)
    private LocalDate paymentDate;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "exchange_rate", nullable = false)
    @Builder.Default
    private BigDecimal exchangeRate = BigDecimal.ONE;

    @Column(name = "base_amount", nullable = false)
    private BigDecimal baseAmount;

    @Column(name = "payment_mode", nullable = false, length = 30)
    private String paymentMode;

    /** GL Cash/Bank account that was debited to make this payment. */
    @Column(name = "paid_through_id", nullable = false)
    private UUID paidThroughId;

    @Column(name = "reference_number", length = 100)
    private String referenceNumber;

    @Column(name = "tds_amount")
    @Builder.Default
    private BigDecimal tdsAmount = BigDecimal.ZERO;

    @Column(name = "tds_section", length = 20)
    private String tdsSection;

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

    @OneToMany(mappedBy = "vendorPayment", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<VendorPaymentAllocation> allocations = new ArrayList<>();

    public void addAllocation(VendorPaymentAllocation alloc) {
        allocations.add(alloc);
        alloc.setVendorPayment(this);
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
