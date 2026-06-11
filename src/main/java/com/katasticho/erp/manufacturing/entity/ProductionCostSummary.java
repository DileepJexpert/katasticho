package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "production_cost_summary")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class ProductionCostSummary extends BaseEntity {

    @Column(name = "work_order_id", nullable = false)
    private UUID workOrderId;

    @Column(name = "work_order_number", nullable = false, length = 30)
    private String workOrderNumber;

    @Column(name = "finished_good_id", nullable = false)
    private UUID finishedGoodId;

    @Builder.Default
    @Column(name = "planned_rm_cost")
    private BigDecimal plannedRmCost = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "actual_rm_cost")
    private BigDecimal actualRmCost = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "planned_labor_cost")
    private BigDecimal plannedLaborCost = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "actual_labor_cost")
    private BigDecimal actualLaborCost = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "planned_overhead")
    private BigDecimal plannedOverhead = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "actual_overhead")
    private BigDecimal actualOverhead = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "planned_total")
    private BigDecimal plannedTotal = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "actual_total")
    private BigDecimal actualTotal = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "material_variance")
    private BigDecimal materialVariance = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "labor_variance")
    private BigDecimal laborVariance = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "overhead_variance")
    private BigDecimal overheadVariance = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "total_variance")
    private BigDecimal totalVariance = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "planned_qty")
    private BigDecimal plannedQty = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "produced_qty")
    private BigDecimal producedQty = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "scrap_qty")
    private BigDecimal scrapQty = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "yield_percentage")
    private BigDecimal yieldPercentage = BigDecimal.ZERO;

    @Column(name = "completed_at")
    private Instant completedAt;
}
