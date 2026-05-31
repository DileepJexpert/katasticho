package com.katasticho.erp.common.workflow;

import java.time.Instant;
import java.util.UUID;

public record ApprovalRequestResponse(
        UUID id,
        UUID workflowId,
        String workflowName,
        String documentType,
        UUID documentId,
        short currentStep,
        String triggerReason,
        String contextJson,
        ApprovalStatus status,
        UUID requestedBy,
        Instant requestedAt,
        Instant resolvedAt,
        Instant createdAt
) {
    public static ApprovalRequestResponse from(ApprovalRequest request) {
        return new ApprovalRequestResponse(
                request.getId(),
                request.getWorkflowDefinition() != null ? request.getWorkflowDefinition().getId() : null,
                request.getWorkflowDefinition() != null ? request.getWorkflowDefinition().getName() : null,
                request.getDocumentType(),
                request.getDocumentId(),
                request.getCurrentStep(),
                request.getTriggerReason(),
                request.getContextJson(),
                request.getStatus(),
                request.getRequestedBy(),
                request.getRequestedAt(),
                request.getResolvedAt(),
                request.getCreatedAt());
    }
}
