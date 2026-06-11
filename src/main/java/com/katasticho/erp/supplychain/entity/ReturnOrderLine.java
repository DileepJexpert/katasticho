package com.katasticho.erp.supplychain.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "return_order_line")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReturnOrderLine extends BaseEntity {

    @Column(name = "return_order_id", nullable = false, insertable = false, updatable = false)
    private UUID returnOrderId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "return_order_id", nullable = false)
    @JsonIgnore
    private ReturnOrder returnOrder;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "batch_id")
    private UUID batchId;

    @Column(nullable = false)
    private BigDecimal quantity;

    @Column(name = "unit_price", nullable = false)
    @Builder.Default
    private BigDecimal unitPrice = BigDecimal.ZERO;

    @Column(name = "line_total", nullable = false)
    @Builder.Default
    private BigDecimal lineTotal = BigDecimal.ZERO;

    @Column(name = "condition", length = 20, nullable = false)
    @Builder.Default
    private String condition = "GOOD";

    @Column(nullable = false)
    @Builder.Default
    private boolean restock = true;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
