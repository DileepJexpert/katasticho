package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * One in-process parameter reading inside a Batch Manufacturing
 * Record (pharma BMR). Captures the measurements the floor takes at
 * each step — temperature during granulation, pH during dissolution,
 * pressure during compression, etc.
 *
 * <p>{@link #jobCardId} is nullable so callers can record WO-level
 * observations that don't belong to one operation step (e.g.,
 * "ambient room temperature at batch start").
 */
@Entity
@Table(name = "bmr_step_record")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class BmrStepRecord extends BaseEntity {

    @Column(name = "work_order_id", nullable = false)
    private UUID workOrderId;

    @Column(name = "job_card_id")
    private UUID jobCardId;

    @Column(name = "parameter_key", nullable = false, length = 100)
    private String parameterKey;

    @Column(name = "parameter_value", nullable = false, length = 200)
    private String parameterValue;

    @Column(length = 20)
    private String unit;

    @Column(name = "observed_at", nullable = false)
    @Builder.Default
    private Instant observedAt = Instant.now();

    @Column(name = "observed_by")
    private UUID observedBy;

    @Column(columnDefinition = "TEXT")
    private String notes;
}
