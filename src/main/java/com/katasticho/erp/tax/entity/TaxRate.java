package com.katasticho.erp.tax.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "tax_rate")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class TaxRate {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "tax_config_id", nullable = false)
    private UUID taxConfigId;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(name = "rate_code", nullable = false, length = 20)
    private String rateCode;

    @Column(nullable = false)
    private BigDecimal percentage;

    @Column(name = "tax_type", nullable = false, length = 20)
    private String taxType;

    @Column(name = "gl_output_account_id")
    private UUID glOutputAccountId;

    @Column(name = "gl_input_account_id")
    private UUID glInputAccountId;

    /**
     * TRUE once the user edits the GL mapping in Settings → Tax Account Mapping.
     * Re-seeders MUST NOT overwrite GL mappings on rows where this is TRUE.
     */
    @Column(name = "is_gl_account_customized", nullable = false)
    @Builder.Default
    private boolean glAccountCustomized = false;

    @Column(name = "is_recoverable", nullable = false)
    @Builder.Default
    private boolean recoverable = true;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
