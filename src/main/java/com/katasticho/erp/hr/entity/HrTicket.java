package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** An HR help-desk ticket raised by an employee. */
@Entity
@Table(name = "hr_ticket")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HrTicket {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "raised_by_user_id", nullable = false)
    private UUID raisedByUserId;

    @Column(nullable = false, length = 40)
    @Builder.Default
    private String category = "GENERAL";

    @Column(nullable = false, length = 200)
    private String subject;

    @Column(columnDefinition = "text")
    private String description;

    /** LOW | NORMAL | HIGH. */
    @Column(nullable = false, length = 10)
    @Builder.Default
    private String priority = "NORMAL";

    /** OPEN | IN_PROGRESS | RESOLVED | CLOSED. */
    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "OPEN";

    @Column(name = "assigned_to_user_id")
    private UUID assignedToUserId;

    @Column(columnDefinition = "text")
    private String resolution;

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
