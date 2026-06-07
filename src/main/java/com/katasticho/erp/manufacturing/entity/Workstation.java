package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@Table(name = "workstation")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Workstation extends BaseEntity {

    @Column(nullable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 100)
    private String name;

    private String description;

    @Column(name = "hourly_rate")
    private BigDecimal hourlyRate;

    @Column(name = "capacity_hours_per_day", nullable = false)
    @Builder.Default
    private BigDecimal capacityHoursPerDay = BigDecimal.valueOf(8);

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;
}
