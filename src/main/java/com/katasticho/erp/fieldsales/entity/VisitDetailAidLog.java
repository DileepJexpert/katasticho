package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** Record of a detail aid presented during a specific field visit. */
@Entity
@Table(name = "visit_detail_aid_log")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VisitDetailAidLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "field_visit_id", nullable = false)
    private UUID fieldVisitId;

    @Column(name = "detail_aid_id", nullable = false)
    private UUID detailAidId;

    @Column(name = "shown_at", nullable = false)
    @Builder.Default
    private Instant shownAt = Instant.now();

    @PrePersist
    protected void onCreate() {
        if (this.orgId == null) {
            this.orgId = TenantContext.getCurrentOrgId();
        }
    }
}
