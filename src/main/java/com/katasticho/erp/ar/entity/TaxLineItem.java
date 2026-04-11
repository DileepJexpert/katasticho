package com.katasticho.erp.ar.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Generic tax line item — reusable across AR (invoices, credit notes) and AP (bills, expenses).
 * Each row represents one tax component (CGST, SGST, IGST, etc.) for one source line.
 */
@Entity
@Table(name = "tax_line_item")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaxLineItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType;

    @Column(name = "source_id", nullable = false)
    private UUID sourceId;

    @Column(name = "source_line_id")
    private UUID sourceLineId;

    @Column(name = "tax_regime", nullable = false, length = 30)
    private String taxRegime;

    @Column(name = "component_code", nullable = false, length = 10)
    private String componentCode;

    @Column(nullable = false)
    private BigDecimal rate;

    @Column(name = "taxable_amount", nullable = false)
    private BigDecimal taxableAmount;

    @Column(name = "tax_amount", nullable = false)
    private BigDecimal taxAmount;

    @Column(name = "account_code", nullable = false, length = 20)
    private String accountCode;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    // Base currency
    @Column(name = "base_taxable_amount")
    @Builder.Default
    private BigDecimal baseTaxableAmount = BigDecimal.ZERO;

    @Column(name = "base_tax_amount")
    @Builder.Default
    private BigDecimal baseTaxAmount = BigDecimal.ZERO;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
