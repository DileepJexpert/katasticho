package com.katasticho.erp.gst.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * One supplier-invoice row parsed from an uploaded GSTR-2B portal JSON.
 *
 * <p>After upload the reconciler matches each row against posted purchase
 * bills (by supplier GSTIN + normalized invoice number) and stamps
 * {@code matchStatus}: MATCHED, VALUE_MISMATCH, or NOT_IN_BOOKS. Mismatches
 * also land in the AI Inbox for review.
 */
@Entity
@Table(name = "gstr2b_entry")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Gstr2bEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    /** Return period as YYYY-MM. */
    @Column(name = "return_period", nullable = false, length = 7)
    private String returnPeriod;

    @Column(name = "supplier_gstin", nullable = false, length = 15)
    private String supplierGstin;

    @Column(name = "supplier_name")
    private String supplierName;

    @Column(name = "invoice_number", nullable = false, length = 100)
    private String invoiceNumber;

    @Column(name = "invoice_date")
    private LocalDate invoiceDate;

    @Column(name = "invoice_value", nullable = false)
    @Builder.Default
    private BigDecimal invoiceValue = BigDecimal.ZERO;

    @Column(name = "taxable_value", nullable = false)
    @Builder.Default
    private BigDecimal taxableValue = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal igst = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal cgst = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal sgst = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal cess = BigDecimal.ZERO;

    @Column(name = "itc_available", nullable = false)
    @Builder.Default
    private boolean itcAvailable = true;

    /** UNMATCHED → MATCHED / VALUE_MISMATCH / NOT_IN_BOOKS. */
    @Column(name = "match_status", nullable = false, length = 30)
    @Builder.Default
    private String matchStatus = "UNMATCHED";

    @Column(name = "matched_bill_id")
    private UUID matchedBillId;

    @Column(name = "match_note", columnDefinition = "text")
    private String matchNote;

    // ── IMS lifecycle (per amended Sec 38 CGST, eff. 1 Oct 2025) ──
    // Buyer must Accept / Reject / Pending each row; null = no action taken
    // = deemed-accepted into GSTR-2B at portal cutoff.

    /** ACCEPT | REJECT | PENDING; null until buyer acts. */
    @Column(name = "ims_action", length = 20)
    private String imsAction;

    @Column(name = "ims_action_at")
    private Instant imsActionAt;

    @Column(name = "ims_action_by")
    private UUID imsActionBy;

    @Column(name = "ims_remarks", columnDefinition = "text")
    private String imsRemarks;

    /** AI's suggested action (ACCEPT/REJECT/PENDING). Human still applies it. */
    @Column(name = "ims_ai_recommendation", length = 20)
    private String imsAiRecommendation;

    @Column(name = "ims_ai_reason", columnDefinition = "text")
    private String imsAiReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    /** Total ITC carried by this 2B row. */
    public BigDecimal totalTax() {
        return igst.add(cgst).add(sgst).add(cess);
    }
}
