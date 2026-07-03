package com.katasticho.erp.workflow.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.List;

/**
 * A user-defined automation: when a {@code triggerEvent} fires for
 * {@code entityType} and the document matches {@code criteria}, run
 * {@code actions}. Rides the existing domain-event bus via
 * {@code WorkflowRuleDomainEventHandler}.
 */
@Entity
@Table(name = "workflow_rule")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkflowRule extends BaseEntity {

    @Column(nullable = false, length = 200)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "entity_type", nullable = false, length = 50)
    private String entityType;

    @Column(name = "trigger_event", nullable = false, length = 80)
    private String triggerEvent;

    @Column(name = "match_type", nullable = false, length = 3)
    @Builder.Default
    private String matchType = "ALL";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<WorkflowCriterion> criteria = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", nullable = false)
    @Builder.Default
    private List<WorkflowAction> actions = new ArrayList<>();

    @Column(nullable = false)
    @Builder.Default
    private boolean active = false;

    @Column(name = "run_order", nullable = false)
    @Builder.Default
    private int runOrder = 0;
}
