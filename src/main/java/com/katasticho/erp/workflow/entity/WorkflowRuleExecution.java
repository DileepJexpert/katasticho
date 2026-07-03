package com.katasticho.erp.workflow.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Audit + idempotency log: one row per (rule, event) evaluation. */
@Entity
@Table(name = "workflow_rule_execution")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkflowRuleExecution extends BaseEntity {

    @Column(name = "rule_id", nullable = false)
    private UUID ruleId;

    @Column(name = "event_id")
    private UUID eventId;

    @Column(name = "entity_type", length = 50)
    private String entityType;

    @Column(name = "entity_id")
    private UUID entityId;

    @Column(nullable = false)
    private boolean matched;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "actions_run", nullable = false)
    @Builder.Default
    private int actionsRun = 0;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    @Builder.Default
    private Map<String, Object> detail = new HashMap<>();
}
