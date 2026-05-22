package com.katasticho.erp.accounting.dto;

import com.katasticho.erp.accounting.entity.FiscalPeriod;

import java.time.Instant;
import java.util.UUID;

public record FiscalPeriodResponse(
        UUID id,
        int periodYear,
        int periodMonth,
        String status,
        Instant closedAt,
        UUID closedBy,
        Instant createdAt,
        Instant updatedAt
) {
    public static FiscalPeriodResponse from(FiscalPeriod period) {
        return new FiscalPeriodResponse(
                period.getId(),
                period.getPeriodYear(),
                period.getPeriodMonth(),
                period.getStatus(),
                period.getClosedAt(),
                period.getClosedBy(),
                period.getCreatedAt(),
                period.getUpdatedAt()
        );
    }
}
