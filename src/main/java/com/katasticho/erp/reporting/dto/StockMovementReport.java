package com.katasticho.erp.reporting.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record StockMovementReport(
    LocalDate startDate,
    LocalDate endDate,
    UUID itemId,
    List<StockMovementReport.Movement> movements
) {
    public record Movement(
        LocalDate movementDate,
        String movementType,
        String itemName,
        String itemSku,
        BigDecimal quantity,
        BigDecimal unitCost,
        BigDecimal totalCost,
        String referenceType,
        String referenceNumber,
        String notes,
        BigDecimal balanceAfter
    ) {}
}
