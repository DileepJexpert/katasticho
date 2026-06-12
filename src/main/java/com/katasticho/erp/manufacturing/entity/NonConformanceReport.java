package com.katasticho.erp.manufacturing.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "non_conformance_report")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class NonConformanceReport extends BaseEntity {

    @Column(name = "ncr_number", nullable = false, length = 30)
    private String ncrNumber;

    @Column(name = "qc_inspection_id")
    private UUID qcInspectionId;

    @Column(name = "item_id", nullable = false)
    private UUID itemId;

    @Column(name = "batch_number", length = 100)
    private String batchNumber;

    /** MINOR | MAJOR | CRITICAL */
    @Column(nullable = false, length = 10)
    @Builder.Default
    private String severity = "MAJOR";

    @Column(length = 500)
    private String reason;

    @Column(columnDefinition = "TEXT")
    private String description;

    /** OPEN | IN_PROGRESS | CLOSED */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "OPEN";

    @Column(name = "corrective_action", columnDefinition = "TEXT")
    private String correctiveAction;

    @Column(name = "root_cause", columnDefinition = "TEXT")
    private String rootCause;

    @Column(name = "closed_at")
    private Instant closedAt;

    @Column(name = "closed_by")
    private UUID closedBy;
}
