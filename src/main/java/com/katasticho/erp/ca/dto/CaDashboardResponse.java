package com.katasticho.erp.ca.dto;

import java.util.List;

public record CaDashboardResponse(
        long totalClients,
        long criticalCount,
        long gstDueThisWeekCount,
        long unbalancedTrialBalanceCount,
        List<CaClientSummaryResponse> clients
) {
}
