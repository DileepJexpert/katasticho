package com.katasticho.erp.inventory.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record TransferOrderResponse(
        UUID id,
        String transferNumber,
        UUID fromWarehouseId,
        String fromWarehouseName,
        UUID toWarehouseId,
        String toWarehouseName,
        LocalDate transferDate,
        String status,
        String notes,
        Instant shippedAt,
        Instant receivedAt,
        int lineCount,
        List<TransferOrderLineResponse> lines,
        Instant createdAt
) {
    public record TransferOrderLineResponse(
            UUID id,
            UUID itemId,
            String itemName,
            String sku,
            UUID batchId,
            String batchNumber,
            BigDecimal quantity,
            BigDecimal receivedQuantity,
            String notes
    ) {}
}
