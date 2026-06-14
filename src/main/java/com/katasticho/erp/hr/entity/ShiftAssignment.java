package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Assigns a shift to an employee over a date range (open-ended when current). */
@Entity
@Table(name = "hr_shift_assignment")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ShiftAssignment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "shift_id", nullable = false)
    private UUID shiftId;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    /** null = open-ended (the employee's current shift). */
    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "created_by")
    private UUID createdBy;

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
