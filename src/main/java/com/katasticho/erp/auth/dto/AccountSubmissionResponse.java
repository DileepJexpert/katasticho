package com.katasticho.erp.auth.dto;

import java.util.UUID;

public record AccountSubmissionResponse(
        UUID orgId,
        UUID userId,
        String orgName,
        String approvalStatus,
        String message
) {}
