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
 * Vendor credit / debit note — issued when we return goods to a
 * vendor or receive an adjustment. DR Accounts Payable, CR Purchase
 * Returns + reverse GST input credit. The {@link #balance} field
 * tracks the remaining unapplied amount.
 */
@Entity
@Table(name = "vendor_credit")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VendorCredit {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "credit_number", nullable = false, length = 30)
    private String creditNumber;

    @Column(name = "credit_date", nullable = false)
    private LocalDate creditDate;

    /** Original bill this credit relates to (optional). */
    @Column(name = "purchase_bill_id")
    private UUID purchaseBillId;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    // ── Amounts ──────────────────────────────────────────────

    @Builder.Default
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "tax_amount")
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(name = "total_amount")
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    /** Remaining unapplied credit. Starts at total, decreases as applied. */
    @Builder.Default
    private BigDecimal balance = BigDecimal.ZERO;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "exchange_rate", nullable = false)
    @Builder.Default
    private BigDecimal exchangeRate = BigDecimal.ONE;

    // ── Base currency ────────────────────────────────────────

    @Column(name = "base_subtotal")
    @Builder.Default
    private BigDecimal baseSubtotal = BigDecimal.ZERO;

    @Column(name = "base_tax_amount")
    @Builder.Default
    private BigDecimal baseTaxAmount = BigDecimal.ZERO;

    @Column(name = "base_total")
    @Builder.Default
    private BigDecimal baseTotal = BigDecimal.ZERO;

    // ── Tax / journal ────────────────────────────────────────

    @Column(name = "place_of_supply", length = 5)
    private String placeOfSupply;

    @Column(nullable = false)
    private String reason;

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    // ── Audit ────────────────────────────────────────────────

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    // ── Lines ────────────────────────────────────────────────

    @OneToMany(mappedBy = "vendorCredit", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<VendorCreditLine> lines = new ArrayList<>();

    public void addLine(VendorCreditLine line) {
        lines.add(line);
        line.setVendorCredit(this);
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
