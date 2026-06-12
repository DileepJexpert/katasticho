package com.katasticho.erp.fieldsales.entity;

import com.katasticho.erp.common.context.TenantContext;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/** URL-based detail aid (brochure / visual aid) shown during field visits. */
@Entity
@Table(name = "detail_aid")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DetailAid {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(length = 300)
    private String description;

    @Column(name = "media_url", nullable = false)
    private String mediaUrl;

    /** PDF / IMAGE / VIDEO / LINK. */
    @Column(name = "media_type", length = 10)
    @Builder.Default
    private String mediaType = "LINK";

    @Column(name = "product_name", length = 200)
    private String productName;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "created_by")
    private UUID createdBy;

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
