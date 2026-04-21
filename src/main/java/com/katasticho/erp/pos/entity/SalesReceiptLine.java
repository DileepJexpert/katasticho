package com.katasticho.erp.pos.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Line item on a POS sales receipt.
 */
@Entity
@Table(name = "sales_receipt_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SalesReceiptLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "receipt_id", nullable = false)
    private SalesReceipt receipt;

    @Column(name = "line_number", nullable = false)
    private int lineNumber;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(length = 500)
    private String description;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal quantity = BigDecimal.ONE;

    @Column(length = 20)
    private String unit;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal rate = BigDecimal.ZERO;

    @Column(name = "tax_group_id")
    private UUID taxGroupId;

    @Column(name = "hsn_code", length = 8)
    private String hsnCode;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal amount = BigDecimal.ZERO;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(name = "unit_uom_id")
    private UUID unitUomId;

    @Column(name = "unit_conversion_factor", precision = 15, scale = 4)
    private BigDecimal unitConversionFactor;

    @Column(name = "base_quantity", precision = 15, scale = 4)
    private BigDecimal baseQuantity;

    @Column(name = "stock_movement_id")
    private UUID stockMovementId;
}
