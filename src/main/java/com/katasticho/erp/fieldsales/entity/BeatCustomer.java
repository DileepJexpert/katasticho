package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "beat_customer")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BeatCustomer {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "beat_id", nullable = false)
    private UUID beatId;

    @Column(name = "contact_id", nullable = false)
    private UUID contactId;

    @Column(name = "visit_sequence")
    private Integer visitSequence;

    @Column(name = "visit_frequency", length = 20)
    @Builder.Default
    private String visitFrequency = "WEEKLY";

    @Column(name = "geo_latitude")
    private BigDecimal geoLatitude;

    @Column(name = "geo_longitude")
    private BigDecimal geoLongitude;

    private String notes;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;

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
