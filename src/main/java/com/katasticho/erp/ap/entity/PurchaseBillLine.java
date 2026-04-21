package com.katasticho.erp.ap.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Line item on a purchase bill. Uses {@code account_id} (FK to account)
 * rather than account_code so the GL target is always valid.
 */
@Entity
@Table(name = "purchase_bill_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PurchaseBillLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_bill_id", nullable = false)
    private PurchaseBill purchaseBill;

    @Column(name = "line_number", nullable = false)
    private Integer lineNumber;

    @Column(nullable = false, length = 500)
    private String description;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    @Column(name = "item_id")
    private UUID itemId;

    /** GL expense/inventory account this line debits on post. */
    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ONE;

    @Column(name = "unit_price", nullable = false)
    private BigDecimal unitPrice;

    @Column(name = "discount_percent", nullable = false)
    @Builder.Default
    private BigDecimal discountPercent = BigDecimal.ZERO;

    @Column(name = "discount_amount", nullable = false)
    @Builder.Default
    private BigDecimal discountAmount = BigDecimal.ZERO;

    @Column(name = "taxable_amount", nullable = false)
    private BigDecimal taxableAmount;

    @Column(name = "gst_rate", nullable = false)
    @Builder.Default
    private BigDecimal gstRate = BigDecimal.ZERO;

    @Column(name = "tax_group_id")
    private UUID taxGroupId;

    @Column(name = "tax_amount", nullable = false)
    @Builder.Default
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(name = "line_total", nullable = false)
    private BigDecimal lineTotal;

    @Column(name = "unit_uom_id")
    private UUID unitUomId;

    @Column(name = "unit_conversion_factor", precision = 15, scale = 4)
    private BigDecimal unitConversionFactor;

    @Column(name = "base_quantity", precision = 15, scale = 4)
    private BigDecimal baseQuantity;

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
