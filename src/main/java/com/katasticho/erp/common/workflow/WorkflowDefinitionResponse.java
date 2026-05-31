package com.katasticho.erp.common.workflow;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record WorkflowDefinitionResponse(
        UUID id,
        String code,
        String name,
        String documentType,
        boolean active,
        String triggerCondition,
        List<WorkflowStepResponse> steps,
        Instant createdAt
) {
    public static WorkflowDefinitionResponse from(WorkflowDefinition definition) {
        return new WorkflowDefinitionResponse(
                definition.getId(),
                definition.getCode(),
                definition.getName(),
                definition.getDocumentType(),
                definition.isActive(),
                definition.getTriggerCondition(),
                definition.getSteps().stream().map(WorkflowStepResponse::from).toList(),
                definition.getCreatedAt());
    }
}
