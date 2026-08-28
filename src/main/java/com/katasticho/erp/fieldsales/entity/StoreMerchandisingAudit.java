package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "store_merchandising_audit")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StoreMerchandisingAudit extends BaseEntity {

    @Column(name = "field_visit_id", nullable = false)
    private UUID fieldVisitId;

    @Column(name = "route_execution_id", nullable = false)
    private UUID routeExecutionId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "salesperson_id", nullable = false)
    private UUID salespersonId;

    @Enumerated(EnumType.STRING)
    @Column(name = "audit_type", nullable = false, length = 50)
    @Builder.Default
    private MerchandisingAuditType auditType = MerchandisingAuditType.PRIMARY_SHELF;

    @Column(name = "photo_url", columnDefinition = "TEXT")
    private String photoUrl;

    @Column(name = "shelf_share_pct", precision = 5, scale = 2)
    private BigDecimal shelfSharePct;

    @Column(name = "facing_count")
    private Integer facingCount;

    @Column(name = "is_stock_out", nullable = false)
    @Builder.Default
    private boolean isStockOut = false;

    @Column(name = "competitor_brand_names", columnDefinition = "TEXT")
    private String competitorBrandNames;

    @Enumerated(EnumType.STRING)
    @Column(name = "planogram_compliance", nullable = false, length = 30)
    @Builder.Default
    private PlanogramCompliance planogramCompliance = PlanogramCompliance.COMPLIANT;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "audited_at", nullable = false)
    @Builder.Default
    private Instant auditedAt = Instant.now();
}
