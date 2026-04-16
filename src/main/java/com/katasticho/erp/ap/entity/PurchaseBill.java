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
 * Purchase bill — a vendor invoice that we owe. Mirror of
 * {@link com.katasticho.erp.ar.entity.Invoice} but money flows
 * in the opposite direction (DR Expense/Inventory, CR AP).
 */
@Entity
@Table(name = "purchase_bill")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PurchaseBill {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "branch_id")
    private UUID branchId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    /** Our internal auto-generated number (BILL-YYYY-NNNN). */
    @Column(name = "bill_number", nullable = false, length = 30)
    private String billNumber;

    /** Vendor's own invoice/reference number (e.g. INV-4521). */
    @Column(name = "vendor_bill_number", length = 100)
    private String vendorBillNumber;

    @Column(name = "bill_date", nullable = false)
    private LocalDate billDate;

    @Column(name = "due_date", nullable = false)
    private LocalDate dueDate;

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

    @Column(name = "amount_paid")
    @Builder.Default
    private BigDecimal amountPaid = BigDecimal.ZERO;

    @Column(name = "balance_due")
    @Builder.Default
    private BigDecimal balanceDue = BigDecimal.ZERO;

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

    // ── Tax context ──────────────────────────────────────────

    @Column(name = "place_of_supply", length = 5)
    private String placeOfSupply;

    @Column(name = "is_reverse_charge", nullable = false)
    @Builder.Default
    private boolean reverseCharge = false;

    @Column(name = "tds_amount")
    @Builder.Default
    private BigDecimal tdsAmount = BigDecimal.ZERO;

    @Column(name = "tds_section", length = 20)
    private String tdsSection;

    // ── Journal / notes ──────────────────────────────────────

    @Column(name = "journal_entry_id")
    private UUID journalEntryId;

    private String notes;

    @Column(name = "terms_and_conditions")
    private String termsAndConditions;

    @Column(name = "period_year")
    private Integer periodYear;

    @Column(name = "period_month")
    private Integer periodMonth;

    // ── Lifecycle ────────────────────────────────────────────

    @Column(name = "posted_at")
    private Instant postedAt;

    @Column(name = "voided_at")
    private Instant voidedAt;

    @Column(name = "voided_by")
    private UUID voidedBy;

    @Column(name = "void_reason")
    private String voidReason;

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

    @OneToMany(mappedBy = "purchaseBill", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<PurchaseBillLine> lines = new ArrayList<>();

    public void addLine(PurchaseBillLine line) {
        lines.add(line);
        line.setPurchaseBill(this);
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
