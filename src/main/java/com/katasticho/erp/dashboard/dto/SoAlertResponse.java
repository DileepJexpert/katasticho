package com.katasticho.erp.dashboard.dto;

import java.math.BigDecimal;
import java.util.List;

public record SoAlertResponse(
        long confirmedCount,
        long backorderCount,
        long partiallyShippedCount,
        long overdueCount,        // confirmed/backorder older than 2 days
        long draftChallanCount,
        long dispatchedChallanCount,
        long deliveredChallanCount,
        List<SoAlertItem> recentOrders
) {
    public record SoAlertItem(
            String id,
            String orderNumber,
            String contactName,
            String status,
            BigDecimal totalAmount,
            String orderDate,
            int daysPending
    ) {}
}
