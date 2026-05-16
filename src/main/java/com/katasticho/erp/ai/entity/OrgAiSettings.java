package com.katasticho.erp.ai.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "org_ai_settings")
@Getter @Setter
public class OrgAiSettings {
    @Id
    @Column(name = "org_id")
    private UUID orgId;

    @Column(name = "provider", nullable = false)
    private String provider = "CLAUDE";

    @Column(name = "model_name", nullable = false)
    private String modelName = "claude-sonnet-4-20250514";

    @Column(name = "base_url")
    private String baseUrl;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(name = "updated_by")
    private UUID updatedBy;

    @PreUpdate
    void onUpdate() { this.updatedAt = Instant.now(); }
}
