package com.katasticho.erp.supplychain.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "supplier_performance")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SupplierPerformance extends BaseEntity {

    @Column(name = "supplier_id", nullable = false)
    private UUID supplierId;

    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Column(name = "period_end", nullable = false)
    private LocalDate periodEnd;

    @Column(name = "total_orders", nullable = false)
    @Builder.Default
    private Integer totalOrders = 0;

    @Column(name = "on_time_deliveries", nullable = false)
    @Builder.Default
    private Integer onTimeDeliveries = 0;

    @Column(name = "late_deliveries", nullable = false)
    @Builder.Default
    private Integer lateDeliveries = 0;

    @Column(name = "total_qty_ordered", nullable = false)
    @Builder.Default
    private BigDecimal totalQtyOrdered = BigDecimal.ZERO;

    @Column(name = "total_qty_received", nullable = false)
    @Builder.Default
    private BigDecimal totalQtyReceived = BigDecimal.ZERO;

    @Column(name = "total_qty_rejected", nullable = false)
    @Builder.Default
    private BigDecimal totalQtyRejected = BigDecimal.ZERO;

    @Column(name = "total_amount", nullable = false)
    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "avg_lead_time_days", nullable = false)
    @Builder.Default
    private BigDecimal avgLeadTimeDays = BigDecimal.ZERO;

    @Column(name = "on_time_rate", nullable = false)
    @Builder.Default
    private BigDecimal onTimeRate = BigDecimal.ZERO;

    @Column(name = "quality_rate", nullable = false)
    @Builder.Default
    private BigDecimal qualityRate = BigDecimal.ZERO;

    @Column(name = "overall_score", nullable = false)
    @Builder.Default
    private BigDecimal overallScore = BigDecimal.ZERO;
}
