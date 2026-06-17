package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * One maintenance event on a workstation. Lifecycle:
 * DRAFT → IN_PROGRESS (records startedAt) → COMPLETED (records completedAt
 * + downtimeMinutes; if linked to a schedule, rolls its nextDueDate forward)
 * → CANCELLED is reachable from DRAFT/IN_PROGRESS.
 */
@Entity
@Table(name = "maintenance_work_order")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class MaintenanceWorkOrder extends BaseEntity {

    @Column(name = "mwo_number", nullable = false, length = 30)
    private String mwoNumber;

    @Column(name = "workstation_id", nullable = false)
    private UUID workstationId;

    /** Null for ad-hoc breakdown work orders; set for schedule-driven ones. */
    @Column(name = "schedule_id")
    private UUID scheduleId;

    @Column(name = "maintenance_type", nullable = false, length = 20)
    private String maintenanceType;          // PREVENTIVE|BREAKDOWN|INSPECTION

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";         // DRAFT|IN_PROGRESS|COMPLETED|CANCELLED

    @Column(nullable = false, length = 10)
    @Builder.Default
    private String priority = "NORMAL";      // URGENT|HIGH|NORMAL|LOW

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "reported_at", nullable = false)
    @Builder.Default
    private Instant reportedAt = Instant.now();

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "downtime_minutes")
    private Integer downtimeMinutes;

    @Column
    private BigDecimal cost;

    @Column(name = "assigned_to_user_id")
    private UUID assignedToUserId;

    @Column(name = "completed_by")
    private UUID completedBy;

    @Column(name = "completion_notes", columnDefinition = "text")
    private String completionNotes;
}
