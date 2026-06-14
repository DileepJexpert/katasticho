package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** One time log: hours against a project/task on a date, with a submit/approve lifecycle. */
@Entity
@Table(name = "hr_timesheet_entry")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TimesheetEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(length = 150)
    private String project;

    @Column(length = 200)
    private String task;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal hours = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private boolean billable = false;

    @Column(columnDefinition = "text")
    private String notes;

    /** DRAFT -> SUBMITTED -> APPROVED | REJECTED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "DRAFT";

    @Column(name = "approved_by")
    private UUID approvedBy;

    @Column(name = "decided_at")
    private Instant decidedAt;

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
    void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
