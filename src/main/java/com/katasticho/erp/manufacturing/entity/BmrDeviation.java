package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * A deviation from the master formula / approved process — logged at
 * any point during the batch and tracked through investigation to
 * resolution. Schedule M requires every batch's BMR to list its
 * deviations alongside the QA disposition.
 *
 * <p>Severity = MINOR | MAJOR | CRITICAL (DB CHECK).
 * Status = OPEN | INVESTIGATING | RESOLVED | ACCEPTED (DB CHECK).
 * "ACCEPTED" covers the case where QA approves a deviation under
 * formal change control rather than fixing it.
 */
@Entity
@Table(name = "bmr_deviation")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class BmrDeviation extends BaseEntity {

    @Column(name = "work_order_id", nullable = false)
    private UUID workOrderId;

    @Column(name = "job_card_id")
    private UUID jobCardId;

    @Column(nullable = false, length = 20)
    private String severity;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "reported_by")
    private UUID reportedBy;

    @Column(name = "reported_at", nullable = false)
    @Builder.Default
    private Instant reportedAt = Instant.now();

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "OPEN";

    @Column(columnDefinition = "TEXT")
    private String resolution;

    @Column(name = "resolved_by")
    private UUID resolvedBy;

    @Column(name = "resolved_at")
    private Instant resolvedAt;
}
