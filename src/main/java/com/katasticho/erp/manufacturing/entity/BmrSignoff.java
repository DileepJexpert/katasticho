package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * One sign-off entry on a BMR — captures who signed for what role at
 * what time. Schedule M / WHO-GMP require operator + supervisor
 * sign-off at each critical step plus QA release at batch close.
 *
 * <p>Role enum is enforced by a DB CHECK: OPERATOR | SUPERVISOR |
 * QA | QC. A JC can carry multiple sign-offs (one per role); a
 * WO-level signoff (e.g., QA release) leaves {@link #jobCardId} NULL.
 */
@Entity
@Table(name = "bmr_signoff")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class BmrSignoff extends BaseEntity {

    @Column(name = "work_order_id", nullable = false)
    private UUID workOrderId;

    @Column(name = "job_card_id")
    private UUID jobCardId;

    @Column(nullable = false, length = 20)
    private String role;

    @Column(name = "signed_by", nullable = false)
    private UUID signedBy;

    @Column(name = "signed_at", nullable = false)
    @Builder.Default
    private Instant signedAt = Instant.now();

    @Column(columnDefinition = "TEXT")
    private String notes;
}
