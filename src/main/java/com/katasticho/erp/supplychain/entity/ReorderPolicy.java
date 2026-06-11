package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "reorder_policy")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReorderPolicy extends BaseEntity {

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "safety_stock", nullable = false)
    @Builder.Default
    private BigDecimal safetyStock = BigDecimal.ZERO;

    @Column(name = "reorder_point", nullable = false)
    @Builder.Default
    private BigDecimal reorderPoint = BigDecimal.ZERO;

    @Column(name = "reorder_qty", nullable = false)
    @Builder.Default
    private BigDecimal reorderQty = BigDecimal.ZERO;

    @Column(name = "max_stock", nullable = false)
    @Builder.Default
    private BigDecimal maxStock = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal eoq = BigDecimal.ZERO;

    @Column(name = "lead_time_days", nullable = false)
    @Builder.Default
    private Integer leadTimeDays = 7;

    @Column(name = "service_level_pct", nullable = false)
    @Builder.Default
    private BigDecimal serviceLevelPct = new BigDecimal("95.00");

    @Column(name = "abc_class", length = 1)
    private String abcClass;

    @Column(name = "last_calculated")
    private Instant lastCalculated;

    @Column(name = "auto_reorder", nullable = false)
    @Builder.Default
    private boolean autoReorder = false;
}
