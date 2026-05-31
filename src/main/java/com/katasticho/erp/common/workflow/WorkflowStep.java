package com.katasticho.erp.common.workflow;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "workflow_step")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkflowStep extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workflow_definition_id", nullable = false)
    private WorkflowDefinition workflowDefinition;

    @Column(name = "step_number", nullable = false)
    private short stepNumber;

    @Column(name = "approver_role", length = 40)
    private String approverRole;

    @Column(name = "approver_user_id")
    private UUID approverUserId;

    @Column(name = "timeout_hours", nullable = false)
    @Builder.Default
    private short timeoutHours = 24;

    @Column(name = "on_timeout", nullable = false, length = 20)
    @Builder.Default
    private String onTimeout = "ESCALATE";
}
