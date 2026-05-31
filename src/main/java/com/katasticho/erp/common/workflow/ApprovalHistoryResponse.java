package com.katasticho.erp.common.workflow;

import java.util.List;

public record ApprovalHistoryResponse(
        List<ApprovalRequestResponse> requests,
        List<ApprovalDecisionResponse> decisions
) {
}
