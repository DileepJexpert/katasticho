package com.katasticho.erp.common.workflow;

import java.util.UUID;

public record WorkflowStepRequest(
        short stepNumber,
        String approverRole,
        UUID approverUserId,
        Short timeoutHours,
        String onTimeout
) {
}
