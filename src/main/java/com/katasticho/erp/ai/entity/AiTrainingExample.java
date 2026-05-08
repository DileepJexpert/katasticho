package com.katasticho.erp.ai.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "ai_training_example")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiTrainingExample {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "org_id", nullable = false)
    private UUID orgId;

    @Column(name = "source_suggestion_id")
    private UUID sourceSuggestionId;

    @Column(name = "entity_type", nullable = false, length = 50)
    private String entityType;

    @Column(name = "entity_id", nullable = false)
    private UUID entityId;

    @Column(name = "task_type", nullable = false, length = 50)
    private String taskType;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "input_snapshot", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, Object> inputSnapshot = new HashMap<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "ai_output", columnDefinition = "jsonb")
    private Map<String, Object> aiOutput;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "human_output", columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private Map<String, Object> humanOutput = new HashMap<>();

    @Column(name = "correction_type", length = 30)
    private String correctionType;

    @Column(name = "correction_reason", columnDefinition = "text")
    private String correctionReason;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
    }
}
