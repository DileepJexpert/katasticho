package com.katasticho.erp.ca.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ReportDispatchResponse(
        UUID id,
        UUID clientOrgId,
        String periodLabel,
        List<String> reportTypes,
        String sentVia,
        boolean aiCommentary,
        String status,
        Instant sentAt,
        Instant createdAt
) {
}
