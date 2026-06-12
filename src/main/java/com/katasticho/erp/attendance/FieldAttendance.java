package com.katasticho.erp.attendance;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** One attendance row per user per day with GPS-stamped punches. */
@Entity
@Table(name = "field_attendance")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FieldAttendance {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Column(name = "punch_in_at")
    private Instant punchInAt;

    @Column(name = "punch_in_latitude")
    private BigDecimal punchInLatitude;

    @Column(name = "punch_in_longitude")
    private BigDecimal punchInLongitude;

    @Column(name = "punch_out_at")
    private Instant punchOutAt;

    @Column(name = "punch_out_latitude")
    private BigDecimal punchOutLatitude;

    @Column(name = "punch_out_longitude")
    private BigDecimal punchOutLongitude;

    private String notes;

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
