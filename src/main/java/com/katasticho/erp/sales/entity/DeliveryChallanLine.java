package com.katasticho.erp.sales.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "delivery_challan_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeliveryChallanLine {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "delivery_challan_id", nullable = false)
    private DeliveryChallan deliveryChallan;

    @Column(name = "sales_order_line_id", nullable = false)
    private UUID salesOrderLineId;

    @Column(name = "line_number", nullable = false)
    private int lineNumber;

    @Column(name = "item_id")
    private UUID itemId;

    @Column(length = 500)
    private String description;

    @Column(nullable = false)
    private BigDecimal quantity;

    @Column(length = 20)
    private String unit;

    @Column(name = "batch_id")
    private UUID batchId;
}
