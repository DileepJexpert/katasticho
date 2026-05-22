package com.katasticho.erp.ca.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CaClientSummaryResponse(
        UUID linkId,
        UUID clientOrgId,
        String clientOrgName,
        String industry,
        String healthStatus,
        long issueCount,
        String nextDeadlineType,
        LocalDate nextDeadlineDate,
        Instant lastActivity,
        UUID assignedUserId,
        String assignedStaffName,
        String engagementType,
        String status,
        List<String> healthReasons
) {
}
