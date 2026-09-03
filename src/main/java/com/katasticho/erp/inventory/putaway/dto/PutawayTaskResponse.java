package com.katasticho.erp.inventory.putaway.dto;

import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayLine;
import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayTask;
import lombok.Builder;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Builder
public record PutawayTaskResponse(
        UUID id,
        UUID orgId,
        String taskNumber,
        UUID goodsReceiptId,
        UUID warehouseId,
        String sourceLocation,
        String status,
        UUID assignedTo,
        String notes,
        Instant createdAt,
        Instant updatedAt,
        List<PutawayLineResponse> lines
) {
    public static PutawayTaskResponse from(WarehousePutawayTask task) {
        return new PutawayTaskResponse(
                task.getId(),
                task.getOrgId(),
                task.getTaskNumber(),
                task.getGoodsReceiptId(),
                task.getWarehouseId(),
                task.getSourceLocation(),
                task.getStatus(),
                task.getAssignedTo(),
                task.getNotes(),
                task.getCreatedAt(),
                task.getUpdatedAt(),
                task.getLines() != null
                        ? task.getLines().stream().map(PutawayLineResponse::from).toList()
                        : List.of()
        );
    }
}