package com.katasticho.erp.integration.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Entity
@Table(name = "integration_config")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IntegrationConfig extends BaseEntity {

    /** TALLY | ZOHO | BUSY | SAP | CUSTOM */
    @Column(name = "integration_type", length = 30, nullable = false)
    private String integrationType;

    @Column(length = 100, nullable = false)
    private String name;

    @Column(name = "base_url", columnDefinition = "TEXT")
    private String baseUrl;

    /** SHA-256 of the API key — never stored in plaintext. */
    @Column(name = "api_key_hash", columnDefinition = "TEXT")
    private String apiKeyHash;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    @Builder.Default
    private Map<String, Object> settings = new HashMap<>();

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean isActive = true;

    @Column(name = "last_sync_at")
    private Instant lastSyncAt;
}
