package com.katasticho.erp.procurement.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "purchase_order_lines")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PurchaseOrderLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "po_id", nullable = false)
    private UUID poId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(length = 500)
    private String description;

    @Column(nullable = false)
    private BigDecimal quantity;

    @Column(name = "received_quantity", nullable = false)
    @Builder.Default
    private BigDecimal receivedQuantity = BigDecimal.ZERO;

    @Column(name = "unit_price", nullable = false)
    @Builder.Default
    private BigDecimal unitPrice = BigDecimal.ZERO;

    @Column(name = "tax_group_id")
    private UUID taxGroupId;

    @Column(name = "line_total", nullable = false)
    @Builder.Default
    private BigDecimal lineTotal = BigDecimal.ZERO;
}
