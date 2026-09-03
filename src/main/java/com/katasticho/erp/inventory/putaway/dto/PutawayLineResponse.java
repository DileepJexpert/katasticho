package com.katasticho.erp.inventory.putaway.dto;

import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayLine;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Builder
public record PutawayLineResponse(
        UUID id,
        UUID itemId,
        String batchNumber,
        BigDecimal quantity,
        UUID suggestedRackId,
        UUID confirmedRackId,
        String status,
        Instant confirmedAt,
        UUID confirmedBy
) {
    public static PutawayLineResponse from(WarehousePutawayLine line) {
        return new PutawayLineResponse(
                line.getId(),
                line.getItemId(),
                line.getBatchNumber(),
                line.getQuantity(),
                line.getSuggestedRackId(),
                line.getConfirmedRackId(),
                line.getStatus(),
                line.getConfirmedAt(),
                line.getConfirmedBy()
        );
    }
}