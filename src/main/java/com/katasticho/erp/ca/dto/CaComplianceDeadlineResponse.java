package com.katasticho.erp.ca.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record CaComplianceDeadlineResponse(
        UUID id,
        UUID linkId,
        UUID clientOrgId,
        String clientOrgName,
        String deadlineType,
        String periodLabel,
        LocalDate dueDate,
        String status,
        Instant filedAt,
        String filingReference,
        String notes
) {
}
