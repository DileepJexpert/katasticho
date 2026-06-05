package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "route_execution")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RouteExecution extends BaseEntity {

    @Column(name = "route_id", nullable = false)
    private UUID routeId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "van_id")
    private UUID vanId;

    @Column(name = "execution_date", nullable = false)
    private LocalDate executionDate;

    @Column(length = 20)
    @Builder.Default
    private String status = "PLANNED";

    @Column(name = "start_time")
    private Instant startTime;

    @Column(name = "end_time")
    private Instant endTime;

    @Column(name = "start_odometer")
    private BigDecimal startOdometer;

    @Column(name = "end_odometer")
    private BigDecimal endOdometer;

    @Column(name = "planned_visits", nullable = false)
    @Builder.Default
    private int plannedVisits = 0;

    @Column(name = "completed_visits", nullable = false)
    @Builder.Default
    private int completedVisits = 0;

    @Column(name = "skipped_visits", nullable = false)
    @Builder.Default
    private int skippedVisits = 0;

    @Column(name = "total_orders_value", nullable = false)
    @Builder.Default
    private BigDecimal totalOrdersValue = BigDecimal.ZERO;

    @Column(name = "total_collections", nullable = false)
    @Builder.Default
    private BigDecimal totalCollections = BigDecimal.ZERO;

    private String notes;
}
