package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.MovementType;
import com.katasticho.erp.inventory.entity.ReferenceType;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record StockMovementResponse(
        UUID id,
        UUID itemId,
        String itemName,
        String itemSku,
        UUID warehouseId,
        String warehouseName,
        LocalDate movementDate,
        Instant createdAt,
        MovementType movementType,
        BigDecimal quantity,
        BigDecimal unitCost,
        BigDecimal totalCost,
        ReferenceType referenceType,
        UUID referenceId,
        String referenceNumber,
        boolean reversal,
        UUID reversalOfId,
        boolean reversed,
        String notes
) {}
