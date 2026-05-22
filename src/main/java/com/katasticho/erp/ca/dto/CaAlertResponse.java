package com.katasticho.erp.ca.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record CaAlertResponse(
        UUID id,
        UUID clientOrgId,
        String clientOrgName,
        String entityType,
        UUID entityId,
        String suggestionType,
        String title,
        String reasoning,
        String priority,
        BigDecimal priorityScore,
        String status,
        boolean dismissed,
        UUID assignedUserId,
        Map<String, Object> suggestedValue,
        Instant createdAt
) {
}
