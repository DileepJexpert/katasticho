package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "salesman_target")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SalesmanTarget extends BaseEntity {

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "period_type", length = 20)
    @Builder.Default
    private String periodType = "MONTHLY";

    @Column(name = "period_start", nullable = false)
    private LocalDate periodStart;

    @Column(name = "period_end", nullable = false)
    private LocalDate periodEnd;

    @Column(name = "target_type", nullable = false, length = 30)
    private String targetType;

    @Column(name = "target_value", nullable = false)
    private BigDecimal targetValue;

    @Column(name = "achieved_value", nullable = false)
    @Builder.Default
    private BigDecimal achievedValue = BigDecimal.ZERO;

    @Column(name = "achievement_pct", nullable = false)
    @Builder.Default
    private BigDecimal achievementPct = BigDecimal.ZERO;

    @Column(name = "incentive_rate", nullable = false)
    @Builder.Default
    private BigDecimal incentiveRate = BigDecimal.ZERO;

    @Column(name = "incentive_amount", nullable = false)
    @Builder.Default
    private BigDecimal incentiveAmount = BigDecimal.ZERO;

    private String notes;
}
