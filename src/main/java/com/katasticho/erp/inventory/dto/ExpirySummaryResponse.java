package com.katasticho.erp.inventory.dto;

/**
 * Aggregate counts of batches by expiry urgency for the dashboard summary cards.
 *
 * <p>Each count only includes batches with positive on-hand stock.
 */
public record ExpirySummaryResponse(
        int expired,
        int within7Days,
        int within30Days,
        int within90Days
) {
    /**
     * Total batches requiring attention.
     */
    public int total() {
        return expired + within7Days + within30Days + within90Days;
    }
}
