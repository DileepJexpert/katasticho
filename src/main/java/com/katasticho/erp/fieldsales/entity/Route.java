package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "route")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Route extends BaseEntity {

    @Column(nullable = false, length = 30)
    private String code;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(name = "day_of_week", length = 10)
    private String dayOfWeek;

    @Column(length = 20)
    @Builder.Default
    private String frequency = "WEEKLY";

    @Column(name = "warehouse_id")
    private UUID warehouseId;

    @Column(name = "estimated_distance_km")
    private BigDecimal estimatedDistanceKm;

    @Column(name = "estimated_duration_minutes")
    private Integer estimatedDurationMinutes;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;
}
