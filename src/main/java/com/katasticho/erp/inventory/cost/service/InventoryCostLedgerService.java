package com.katasticho.erp.inventory.cost.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.cost.entity.InventoryCostAllocation;
import com.katasticho.erp.inventory.cost.entity.InventoryCostComponent;
import com.katasticho.erp.inventory.cost.entity.InventoryCostEvent;
import com.katasticho.erp.inventory.cost.repository.InventoryCostAllocationRepository;
import com.katasticho.erp.inventory.cost.repository.InventoryCostEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Append-only costing ledger. It never changes stock quantities; it records
 * the cost components and the exact stock movements that received them.
 */
@Service
@RequiredArgsConstructor
public class InventoryCostLedgerService {

    private final InventoryCostEventRepository eventRepository;
    private final InventoryCostAllocationRepository allocationRepository;

    @Transactional
    public InventoryCostEvent recordEvent(String eventType, String sourceType,
                                          UUID sourceId, String sourceNumber,
                                          UUID warehouseId, String allocationBasis,
                                          List<ComponentInput> components,
                                          List<AllocationInput> allocations,
                                          String notes) {
        if (sourceId == null || sourceType == null || sourceType.isBlank()) {
            throw new BusinessException("Cost event source is required",
                    "COST_SOURCE_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        List<ComponentInput> safeComponents = components == null ? List.of() : components;
        List<AllocationInput> safeAllocations = allocations == null ? List.of() : allocations;
        BigDecimal componentTotal = safeComponents.stream()
                .map(c -> nonNegative(c.amount(), "Cost component amount"))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);

        if (componentTotal.signum() <= 0) {
            throw new BusinessException("Cost event must contain a positive cost component",
                    "COST_AMOUNT_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        BigDecimal allocationTotal = safeAllocations.stream()
                .map(a -> nonNegative(a.allocatedAmount(), "Cost allocation amount"))
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
        if (allocationTotal.compareTo(componentTotal) > 0) {
            throw new BusinessException("Allocated cost cannot exceed event cost",
                    "COST_ALLOCATION_EXCEEDS_EVENT", HttpStatus.BAD_REQUEST);
        }

        UUID orgId = TenantContext.getCurrentOrgId();
        InventoryCostEvent event = InventoryCostEvent.builder()
                .eventNumber(nextEventNumber(orgId))
                .eventType(eventType)
                .sourceType(sourceType)
                .sourceId(sourceId)
                .sourceNumber(sourceNumber)
                .warehouseId(warehouseId)
                .totalAmount(componentTotal)
                .allocationBasis(allocationBasis == null ? "DIRECT" : allocationBasis)
                .status("POSTED")
                .notes(notes)
                .components(new java.util.ArrayList<>())
                .allocations(new java.util.ArrayList<>())
                .build();

        for (ComponentInput input : safeComponents) {
            event.addComponent(InventoryCostComponent.builder()
                    .componentType(input.componentType())
                    .description(input.description())
                    .amount(nonNegative(input.amount(), "Cost component amount"))
                    .sourceType(input.sourceType())
                    .sourceId(input.sourceId())
                    .build());
        }
        for (AllocationInput input : safeAllocations) {
            if (input.stockMovementId() == null || input.itemId() == null
                    || input.quantity() == null || input.quantity().signum() <= 0) {
                throw new BusinessException("A cost allocation must identify a positive stock movement quantity",
                        "COST_ALLOCATION_INVALID", HttpStatus.BAD_REQUEST);
            }
            event.addAllocation(InventoryCostAllocation.builder()
                    .stockMovementId(input.stockMovementId())
                    .itemId(input.itemId())
                    .batchId(input.batchId())
                    .quantity(input.quantity())
                    .allocatedAmount(nonNegative(input.allocatedAmount(), "Cost allocation amount"))
                    .unitCostAddition(input.unitCostAddition() == null
                            ? BigDecimal.ZERO : input.unitCostAddition())
                    .build());
        }
        return eventRepository.save(event);
    }

    @Transactional(readOnly = true)
    public List<InventoryCostEvent> findBySource(String sourceType, UUID sourceId) {
        return eventRepository.findByOrgIdAndSourceTypeAndSourceIdAndIsDeletedFalseOrderByCreatedAtAsc(
                TenantContext.getCurrentOrgId(), sourceType, sourceId);
    }

    @Transactional(readOnly = true)
    public List<InventoryCostAllocation> findByMovement(UUID movementId) {
        return allocationRepository.findByOrgIdAndStockMovementIdAndIsDeletedFalseOrderByCreatedAtAsc(
                TenantContext.getCurrentOrgId(), movementId);
    }

    @Transactional(readOnly = true)
    public List<InventoryCostAllocation> findByBatch(UUID batchId) {
        return allocationRepository.findByOrgIdAndBatchIdAndIsDeletedFalseOrderByCreatedAtAsc(
                TenantContext.getCurrentOrgId(), batchId);
    }

    @Transactional(readOnly = true)
    public List<InventoryCostEvent> listRecent() {
        return eventRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId());
    }

    private String nextEventNumber(UUID orgId) {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 10).toUpperCase();
        return "IC-" + LocalDate.now().getYear() + "-" + suffix;
    }

    private static BigDecimal nonNegative(BigDecimal value, String label) {
        if (value == null || value.signum() < 0) {
            throw new BusinessException(label + " cannot be negative",
                    "COST_NEGATIVE_AMOUNT", HttpStatus.BAD_REQUEST);
        }
        return value.setScale(2, RoundingMode.HALF_UP);
    }

    public record ComponentInput(String componentType, String description,
                                 BigDecimal amount, String sourceType, UUID sourceId) {}

    public record AllocationInput(UUID stockMovementId, UUID itemId, UUID batchId,
                                 BigDecimal quantity, BigDecimal allocatedAmount,
                                 BigDecimal unitCostAddition) {}
}
