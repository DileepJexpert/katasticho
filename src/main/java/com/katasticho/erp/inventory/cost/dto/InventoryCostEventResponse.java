package com.katasticho.erp.inventory.cost.dto;

import com.katasticho.erp.inventory.cost.entity.InventoryCostAllocation;
import com.katasticho.erp.inventory.cost.entity.InventoryCostComponent;
import com.katasticho.erp.inventory.cost.entity.InventoryCostEvent;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record InventoryCostEventResponse(
        UUID id,
        String eventNumber,
        String eventType,
        String sourceType,
        UUID sourceId,
        String sourceNumber,
        UUID warehouseId,
        BigDecimal totalAmount,
        String allocationBasis,
        String status,
        String notes,
        Instant createdAt,
        List<Component> components,
        List<Allocation> allocations
) {
    public record Component(
            UUID id,
            String componentType,
            String description,
            BigDecimal amount,
            String sourceType,
            UUID sourceId
    ) {}

    public record Allocation(
            UUID id,
            UUID stockMovementId,
            UUID itemId,
            UUID batchId,
            BigDecimal quantity,
            BigDecimal allocatedAmount,
            BigDecimal unitCostAddition
    ) {}

    public static InventoryCostEventResponse from(InventoryCostEvent event) {
        return new InventoryCostEventResponse(
                event.getId(), event.getEventNumber(), event.getEventType(),
                event.getSourceType(), event.getSourceId(), event.getSourceNumber(),
                event.getWarehouseId(), event.getTotalAmount(), event.getAllocationBasis(),
                event.getStatus(), event.getNotes(), event.getCreatedAt(),
                event.getComponents().stream().filter(c -> !c.isDeleted())
                        .map(InventoryCostEventResponse::component).toList(),
                event.getAllocations().stream().filter(a -> !a.isDeleted())
                        .map(InventoryCostEventResponse::allocation).toList());
    }

    private static Component component(InventoryCostComponent c) {
        return new Component(c.getId(), c.getComponentType(), c.getDescription(),
                c.getAmount(), c.getSourceType(), c.getSourceId());
    }

    private static Allocation allocation(InventoryCostAllocation a) {
        return new Allocation(a.getId(), a.getStockMovementId(), a.getItemId(),
                a.getBatchId(), a.getQuantity(), a.getAllocatedAmount(),
                a.getUnitCostAddition());
    }
}
