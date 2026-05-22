package com.katasticho.erp.ca.dto;

import java.util.List;
import java.util.UUID;

public record ReportDispatchRequest(
        List<UUID> clientOrgIds,
        boolean allClients,
        String periodLabel,
        List<String> reportTypes,
        String sendVia,
        boolean includeAiCommentary,
        String customMessage
) {
}
