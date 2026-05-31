package com.katasticho.erp.common.workflow;

import java.util.UUID;

public record WorkflowStepResponse(
        UUID id,
        short stepNumber,
        String approverRole,
        UUID approverUserId,
        short timeoutHours,
        String onTimeout
) {
    public static WorkflowStepResponse from(WorkflowStep step) {
        return new WorkflowStepResponse(
                step.getId(),
                step.getStepNumber(),
                step.getApproverRole(),
                step.getApproverUserId(),
                step.getTimeoutHours(),
                step.getOnTimeout());
    }
}
