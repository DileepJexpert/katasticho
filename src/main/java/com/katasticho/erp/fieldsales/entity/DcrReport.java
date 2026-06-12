package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Daily Call Report: one per salesperson per day, summarised from field visits. */
@Entity
@Table(name = "dcr_report")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DcrReport {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Column(name = "report_date", nullable = false)
    private LocalDate reportDate;

    @Column(name = "route_execution_id")
    private UUID routeExecutionId;

    /** FIELD_WORK / MEETING / OFFICE / CAMP / LEAVE. */
    @Column(name = "work_type", length = 20)
    @Builder.Default
    private String workType = "FIELD_WORK";

    @Column(name = "doctors_visited", nullable = false)
    @Builder.Default
    private int doctorsVisited = 0;

    @Column(name = "chemists_visited", nullable = false)
    @Builder.Default
    private int chemistsVisited = 0;

    @Column(name = "others_visited", nullable = false)
    @Builder.Default
    private int othersVisited = 0;

    @Column(name = "total_visits", nullable = false)
    @Builder.Default
    private int totalVisits = 0;

    @Column(name = "total_pob", nullable = false)
    @Builder.Default
    private BigDecimal totalPob = BigDecimal.ZERO;

    @Column(name = "samples_given", nullable = false)
    @Builder.Default
    private int samplesGiven = 0;

    private String remarks;

    @Column(length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "rejection_reason", length = 300)
    private String rejectionReason;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
        if (this.orgId == null) {
            this.orgId = TenantContext.getCurrentOrgId();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
