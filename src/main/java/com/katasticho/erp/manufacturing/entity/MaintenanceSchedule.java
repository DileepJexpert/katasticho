package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.util.UUID;

/**
 * A preventive maintenance schedule for a workstation. When a maintenance
 * work order linked to this schedule completes, the service rolls
 * {@code lastCompletedDate} forward and recomputes {@code nextDueDate}.
 */
@Entity
@Table(name = "maintenance_schedule")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class MaintenanceSchedule extends BaseEntity {

    @Column(name = "workstation_id", nullable = false)
    private UUID workstationId;

    @Column(nullable = false, length = 50)
    private String code;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "frequency_days", nullable = false)
    private Integer frequencyDays;

    @Column(name = "last_completed_date")
    private LocalDate lastCompletedDate;

    @Column(name = "next_due_date", nullable = false)
    private LocalDate nextDueDate;

    @Column(name = "estimated_duration_min")
    private Integer estimatedDurationMin;

    @Column(name = "assigned_to_user_id")
    private UUID assignedToUserId;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
}
