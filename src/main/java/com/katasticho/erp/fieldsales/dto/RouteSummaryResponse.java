package com.katasticho.erp.fieldsales.dto;

import java.math.BigDecimal;
import java.util.UUID;

/** Route read model for planning screens, including its current beat-plan size. */
public record RouteSummaryResponse(
        UUID id,
        String code,
        String name,
        String dayOfWeek,
        String frequency,
        UUID warehouseId,
        BigDecimal estimatedDistanceKm,
        Integer estimatedDurationMinutes,
        boolean active,
        long beatCount) {
}
