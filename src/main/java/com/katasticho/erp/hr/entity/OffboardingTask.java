package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** One clearance task in an offboarding checklist. */
@Entity
@Table(name = "hr_offboarding_task")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OffboardingTask {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "offboarding_id", nullable = false)
    private UUID offboardingId;

    @Column(nullable = false, length = 200)
    private String label;

    /** IT | FINANCE | HR | ADMIN | OTHER. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String category = "OTHER";

    @Column(nullable = false)
    @Builder.Default
    private boolean completed = false;

    @Column(name = "completed_by")
    private UUID completedBy;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = Instant.now();
    }
}
