package com.katasticho.erp.auth.dto;

import java.util.UUID;

public record OrgSummary(
        UUID orgId,
        String orgName,
        UUID userId,
        String role
) {}
