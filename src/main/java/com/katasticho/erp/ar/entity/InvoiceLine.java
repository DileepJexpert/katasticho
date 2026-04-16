package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "invoice_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InvoiceLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "invoice_id", nullable = false)
    private Invoice invoice;

    @Column(name = "line_number", nullable = false)
    private Integer lineNumber;

    @Column(nullable = false, length = 500)
    private String description;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

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

    @Column(name = "account_code", nullable = false, length = 20)
    private String accountCode;

    /**
     * Optional link to {@code item.id}. Free-text invoice lines (item_id = NULL)
     * remain valid; only itemised lines flow through inventory.
     */
    @Column(name = "item_id")
    private UUID itemId;

    /** Optional batch reference — populated by Sprint 26 perishables. */
    @Column(name = "batch_id")
    private UUID batchId;

    // Base currency
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
