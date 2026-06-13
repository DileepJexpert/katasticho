package com.katasticho.erp.fieldsales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** One product line of a stockist Stock &amp; Sales Statement. */
@Entity
@Table(name = "stockist_sales_line")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StockistSalesLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "statement_id", nullable = false)
    private UUID statementId;

    /** Optional link to the org's item master; product_name always present. */
    @Column(name = "item_id")
    private UUID itemId;

    @Column(name = "product_name", nullable = false)
    private String productName;

    @Column(name = "opening_qty", nullable = false)
    @Builder.Default
    private BigDecimal openingQty = BigDecimal.ZERO;

    @Column(name = "purchase_qty", nullable = false)
    @Builder.Default
    private BigDecimal purchaseQty = BigDecimal.ZERO;

    @Column(name = "sales_qty", nullable = false)
    @Builder.Default
    private BigDecimal salesQty = BigDecimal.ZERO;

    @Column(name = "return_qty", nullable = false)
    @Builder.Default
    private BigDecimal returnQty = BigDecimal.ZERO;

    @Column(name = "closing_qty", nullable = false)
    @Builder.Default
    private BigDecimal closingQty = BigDecimal.ZERO;

    @Column(name = "sales_value", nullable = false)
    @Builder.Default
    private BigDecimal salesValue = BigDecimal.ZERO;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
