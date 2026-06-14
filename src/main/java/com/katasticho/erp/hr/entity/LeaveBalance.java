package com.katasticho.erp.hr.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** A user's leave balance for one leave type in one year. */
@Entity
@Table(name = "hr_leave_balance")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LeaveBalance {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "leave_type_id", nullable = false)
    private UUID leaveTypeId;

    @Column(nullable = false)
    private int year;

    /** Quota granted for the year (from the type, or accrued so far). */
    @Column(nullable = false)
    @Builder.Default
    private BigDecimal entitled = BigDecimal.ZERO;

    @Column(name = "carried_forward", nullable = false)
    @Builder.Default
    private BigDecimal carriedForward = BigDecimal.ZERO;

    @Column(nullable = false)
    @Builder.Default
    private BigDecimal used = BigDecimal.ZERO;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Transient
    public BigDecimal getAvailable() {
        return entitled.add(carriedForward).subtract(used);
    }

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
