package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** One planned day inside a {@link TourPlan}. */
@Entity
@Table(name = "tour_plan_entry")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TourPlanEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "tour_plan_id", nullable = false)
    private UUID tourPlanId;

    @Column(name = "plan_date", nullable = false)
    private LocalDate planDate;

    /** FIELD_WORK / MEETING / OFFICE / CAMP / LEAVE. */
    @Column(name = "activity_type", length = 20)
    @Builder.Default
    private String activityType = "FIELD_WORK";

    @Column(name = "beat_id")
    private UUID beatId;

    @Column(length = 150)
    private String area;

    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        if (this.orgId == null) {
            this.orgId = TenantContext.getCurrentOrgId();
        }
    }
}
