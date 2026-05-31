package com.katasticho.erp.common.workflow;

public record WorkflowUpdateRequest(
        Boolean active,
        String triggerCondition
) {
}
