package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "workflow_definition")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkflowDefinition extends BaseEntity {

    @Column(nullable = false, length = 80)
    private String code;

    @Column(nullable = false, length = 160)
    private String name;

    @Column(name = "document_type", nullable = false, length = 80)
    private String documentType;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "trigger_condition", nullable = false, columnDefinition = "jsonb")
    private String triggerCondition;

    @OneToMany(mappedBy = "workflowDefinition", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("stepNumber ASC")
    @Builder.Default
    private List<WorkflowStep> steps = new ArrayList<>();

    public void addStep(WorkflowStep step) {
        steps.add(step);
        step.setWorkflowDefinition(this);
    }

    public void clearSteps() {
        steps.clear();
    }
}
