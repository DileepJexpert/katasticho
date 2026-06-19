package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Corrective &amp; Preventive Action — tracker #88. Companion to
 * {@link NonConformanceReport}: a CAPA records the actual remediation
 * (or planned preventive action) with an owner, due date, and
 * effectiveness review. Standalone (no ncr_id) for preventive actions
 * raised from trends, audits, or customer complaints.
 */
@Entity
@Table(name = "capa_action")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class CapaAction extends BaseEntity {

    @Column(name = "capa_number", nullable = false, length = 30)
    private String capaNumber;

    @Column(name = "ncr_id")
    private UUID ncrId;

    /** CORRECTIVE | PREVENTIVE */
    @Column(name = "capa_type", nullable = false, length = 15)
    private String capaType;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "proposed_action", columnDefinition = "TEXT")
    private String proposedAction;

    @Column(name = "assigned_to")
    private UUID assignedTo;

    @Column(name = "due_date")
    private LocalDate dueDate;

    /** URGENT | HIGH | NORMAL | LOW */
    @Column(nullable = false, length = 10)
    @Builder.Default
    private String priority = "NORMAL";

    /** OPEN | IN_PROGRESS | COMPLETED | VERIFIED | CANCELLED */
    @Column(nullable = false, length = 15)
    @Builder.Default
    private String status = "OPEN";

    @Column(name = "completion_notes", columnDefinition = "TEXT")
    private String completionNotes;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "completed_by")
    private UUID completedBy;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "verified_by")
    private UUID verifiedBy;

    @Column(name = "effectiveness_notes", columnDefinition = "TEXT")
    private String effectivenessNotes;
}
