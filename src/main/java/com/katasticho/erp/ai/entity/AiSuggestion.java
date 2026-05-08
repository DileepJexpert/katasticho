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
@Table(name = "ai_suggestion")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiSuggestion {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "entity_type", nullable = false, length = 50)
    private String entityType;

    @Column(name = "entity_id", nullable = false)
    private UUID entityId;

    @Column(name = "entity_line_id")
    private UUID entityLineId;

    @Column(name = "suggestion_type", nullable = false, length = 50)
    private String suggestionType;

    @Column(name = "suggested_action", length = 80)
    private String suggestedAction;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "suggested_value", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, Object> suggestedValue = new HashMap<>();

    @Column(columnDefinition = "text")
    private String reasoning;

    @Column(precision = 4, scale = 3)
    private BigDecimal confidence;

    @Column(name = "agent_name", length = 50)
    private String agentName;

    @Column(name = "model_name", length = 80)
    private String modelName;

    @Column(name = "model_version", length = 50)
    private String modelVersion;

    @Column(name = "prompt_version", length = 50)
    private String promptVersion;

    @Column(nullable = false, length = 30)
    @Builder.Default
    private String status = "PENDING";

    @Column(name = "reviewed_by")
    private UUID reviewedBy;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @Column(name = "review_action", length = 50)
    private String reviewAction;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "reviewed_value", columnDefinition = "jsonb")
    private Map<String, Object> reviewedValue;

    @Column(name = "correction_reason", columnDefinition = "text")
    private String correctionReason;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String priority = "MEDIUM";

    @Column(name = "priority_score", nullable = false, precision = 8, scale = 3)
    @Builder.Default
    private BigDecimal priorityScore = BigDecimal.ZERO;

    @Column(name = "due_by")
    private Instant dueBy;

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
