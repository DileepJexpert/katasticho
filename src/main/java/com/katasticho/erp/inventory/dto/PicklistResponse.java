package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PicklistResponse(
        UUID id,
        String picklistNumber,
        UUID salesOrderId,
        String salesOrderNumber,
        UUID warehouseId,
        String warehouseName,
        String status,
        UUID assignedTo,
        String notes,
        Instant startedAt,
        Instant completedAt,
        int lineCount,
        int pickedCount,
        List<PicklistLineResponse> lines,
        Instant createdAt
) {
    public record PicklistLineResponse(
            UUID id,
            UUID salesOrderLineId,
            UUID itemId,
            String itemName,
            String sku,
            BigDecimal requiredQuantity,
            BigDecimal pickedQuantity,
            UUID batchId,
            String batchNumber,
            UUID rackLocationId,
            String rackLocationCode,
            String notes
    ) {}
}
