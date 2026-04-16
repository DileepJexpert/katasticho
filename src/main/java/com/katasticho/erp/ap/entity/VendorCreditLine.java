package com.katasticho.erp.ap.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Line item on a vendor credit. Same shape as
 * {@link PurchaseBillLine} minus discount fields (credits
 * match the original bill line values).
 */
@Entity
@Table(name = "vendor_credit_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VendorCreditLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vendor_credit_id", nullable = false)
    private VendorCredit vendorCredit;

    @Column(name = "line_number", nullable = false)
    private Integer lineNumber;

    @Column(nullable = false, length = 500)
    private String description;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    @Column(name = "item_id")
    private UUID itemId;

    /** GL account this line credits on post. */
    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ONE;

    @Column(name = "unit_price", nullable = false)
    private BigDecimal unitPrice;

    @Column(name = "taxable_amount", nullable = false)
    private BigDecimal taxableAmount;

    @Column(name = "gst_rate", nullable = false)
    @Builder.Default
    private BigDecimal gstRate = BigDecimal.ZERO;

    @Column(name = "tax_amount", nullable = false)
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(name = "line_total", nullable = false)
    private BigDecimal lineTotal;

    // ── Base currency ────────────────────────────────────────

    @Column(name = "base_taxable_amount")
    @Builder.Default
    private BigDecimal baseTaxableAmount = BigDecimal.ZERO;

    @Column(name = "base_tax_amount")
    @Builder.Default
    private BigDecimal baseTaxAmount = BigDecimal.ZERO;

    @Column(name = "base_line_total")
    @Builder.Default
    private BigDecimal baseLineTotal = BigDecimal.ZERO;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
