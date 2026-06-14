package com.katasticho.erp.attendance;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** A request to correct/add an attendance punch for a past date. */
@Entity
@Table(name = "attendance_regularization")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AttendanceRegularization {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "requested_punch_in")
    private Instant requestedPunchIn;

    @Column(name = "requested_punch_out")
    private Instant requestedPunchOut;

    @Column(columnDefinition = "text")
    private String reason;

    /** PENDING -> APPROVED | REJECTED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "PENDING";

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
