package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Projection of a near-expiry batch for the dashboard.
 *
 * <p>{@code daysUntilExpiry} can be negative (already expired).
 * {@code urgency} is one of: EXPIRED, CRITICAL (<=7d), WARNING (<=30d), OK (<=90d).
 */
public record ExpiryBatchResponse(
        UUID batchId,
        UUID itemId,
        String itemName,
        String batchNumber,
        LocalDate expiryDate,
        BigDecimal quantityOnHand,
        long daysUntilExpiry,
        String urgency
) {
}
