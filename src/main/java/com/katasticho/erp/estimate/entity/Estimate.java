package com.katasticho.erp.estimate.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * A sales quotation / estimate. Unlike invoices, estimates do NOT post
 * any journal entries — their totals are informational until the
 * estimate is converted into an invoice (which creates a fresh DRAFT
 * invoice that follows the usual AR posting rules).
 */
@Entity
@Table(name = "estimate")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Estimate {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false, updatable = false)
    private UUID orgId;

    @Column(name = "estimate_number", nullable = false, length = 30)
    private String estimateNumber;

    /** Buyer — unified contact (CUSTOMER or BOTH). */
    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "estimate_date", nullable = false)
    private LocalDate estimateDate;

    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "discount_amount", nullable = false)
    @Builder.Default
    private BigDecimal discountAmount = BigDecimal.ZERO;

    @Column(name = "tax_amount", nullable = false)
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal total = BigDecimal.ZERO;

    @Column(nullable = false, length = 3)
    @Builder.Default
    private String currency = "INR";

    @Column(name = "reference_number", length = 60)
    private String referenceNumber;

    @Column(length = 200)
    private String subject;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(columnDefinition = "TEXT")
    private String terms;

    /** Set once the estimate has been converted — points at the draft invoice. */
    @Column(name = "converted_to_invoice_id")
    private UUID convertedToInvoiceId;

    @Column(name = "converted_at")
    private Instant convertedAt;

    @Column(name = "sent_at")
    private Instant sentAt;

    @Column(name = "accepted_at")
    private Instant acceptedAt;

    @Column(name = "declined_at")
    private Instant declinedAt;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @OneToMany(mappedBy = "estimate", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<EstimateLine> lines = new ArrayList<>();

    public void addLine(EstimateLine line) {
        lines.add(line);
        line.setEstimate(this);
    }

    public void clearLines() {
        for (EstimateLine l : lines) {
            l.setEstimate(null);
        }
        lines.clear();
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
