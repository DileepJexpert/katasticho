package com.katasticho.erp.common.workflow;

import java.time.Instant;
import java.util.UUID;

public record ApprovalDecisionResponse(
        UUID id,
        UUID approvalRequestId,
        short stepNumber,
        ApprovalStatus decision,
        String note,
        UUID decidedBy,
        Instant decidedAt
) {
    public static ApprovalDecisionResponse from(ApprovalDecision decision) {
        return new ApprovalDecisionResponse(
                decision.getId(),
                decision.getApprovalRequest() != null ? decision.getApprovalRequest().getId() : null,
                decision.getStepNumber(),
                decision.getDecision(),
                decision.getNote(),
                decision.getDecidedBy(),
                decision.getDecidedAt());
    }
}
