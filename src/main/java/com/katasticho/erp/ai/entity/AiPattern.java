package com.katasticho.erp.ai.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "ai_pattern")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiPattern {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "pattern_type", nullable = false, length = 50)
    private String patternType;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "pattern_key", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, Object> patternKey = new HashMap<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "predicted_result", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, Object> predictedResult = new HashMap<>();

    @Column(nullable = false, precision = 4, scale = 3)
    @Builder.Default
    private BigDecimal confidence = new BigDecimal("0.500");

    @Column(name = "match_count", nullable = false)
    @Builder.Default
    private int matchCount = 0;

    @Column(name = "accepted_count", nullable = false)
    @Builder.Default
    private int acceptedCount = 0;

    @Column(name = "rejected_count", nullable = false)
    @Builder.Default
    private int rejectedCount = 0;

    @Column(name = "corrected_count", nullable = false)
    @Builder.Default
    private int correctedCount = 0;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "last_matched_at")
    private Instant lastMatchedAt;

    @Column(name = "last_corrected_at")
    private Instant lastCorrectedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
