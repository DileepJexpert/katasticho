package com.katasticho.erp.sales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "sales_order_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalesOrderLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sales_order_id", nullable = false)
    private SalesOrder salesOrder;

    @Column(name = "line_number", nullable = false)
    private int lineNumber;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(length = 500)
    private String description;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ZERO;

    @Column(name = "quantity_shipped", nullable = false)
    @Builder.Default
    private BigDecimal quantityShipped = BigDecimal.ZERO;

    @Column(name = "quantity_invoiced", nullable = false)
    @Builder.Default
    private BigDecimal quantityInvoiced = BigDecimal.ZERO;

    @Column(length = 20)
    private String unit;

    @Column(nullable = false)
    private BigDecimal rate;

    @Column(name = "discount_pct", nullable = false)
    @Builder.Default
    private BigDecimal discountPct = BigDecimal.ZERO;

    @Column(name = "tax_group_id")
    private UUID taxGroupId;

    @Column(name = "tax_rate", nullable = false)
    @Builder.Default
    private BigDecimal taxRate = BigDecimal.ZERO;

    @Column(name = "hsn_code", length = 10)
    private String hsnCode;

    @Column(nullable = false)
    private BigDecimal amount;
}
