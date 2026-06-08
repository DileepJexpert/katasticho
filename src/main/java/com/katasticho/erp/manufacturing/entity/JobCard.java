package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "job_card")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class JobCard extends BaseEntity {

    @Column(name = "work_order_id", nullable = false)
    private UUID workOrderId;

    @Column(name = "operation_id", nullable = false)
    private UUID operationId;

    @Column(name = "workstation_id")
    private UUID workstationId;

    @Column(name = "sequence_number", nullable = false)
    private int sequenceNumber;

    @Column(name = "assigned_to")
    private UUID assignedTo;

    @Column(length = 20, nullable = false)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "planned_start")
    private Instant plannedStart;

    @Column(name = "planned_end")
    private Instant plannedEnd;

    @Column(name = "actual_start")
    private Instant actualStart;

    @Column(name = "actual_end")
    private Instant actualEnd;

    @Column(name = "planned_qty", nullable = false)
    @Builder.Default
    private BigDecimal plannedQty = BigDecimal.ZERO;

    @Column(name = "completed_qty", nullable = false)
    @Builder.Default
    private BigDecimal completedQty = BigDecimal.ZERO;

    @Column(name = "scrap_qty", nullable = false)
    @Builder.Default
    private BigDecimal scrapQty = BigDecimal.ZERO;

    @Column(name = "time_logged_minutes", nullable = false)
    @Builder.Default
    private int timeLoggedMinutes = 0;

    private String notes;
}
