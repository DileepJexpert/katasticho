package com.katasticho.erp.inventory.putaway.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.putaway.dto.PutawayLineConfirmRequest;
import com.katasticho.erp.inventory.putaway.dto.PutawayTaskRequest;
import com.katasticho.erp.inventory.putaway.dto.PutawayTaskResponse;
import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayLine;
import com.katasticho.erp.inventory.putaway.entity.WarehousePutawayTask;
import com.katasticho.erp.inventory.putaway.repository.WarehousePutawayLineRepository;
import com.katasticho.erp.inventory.putaway.repository.WarehousePutawayTaskRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.RackLocation;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.RackLocationRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;

@Service
@RequiredArgsConstructor
@Slf4j
public class WarehousePutawayService {

    private final WarehousePutawayTaskRepository taskRepository;
    private final WarehousePutawayLineRepository lineRepository;
    private final WarehouseRepository warehouseRepository;
    private final ItemRepository itemRepository;
    private final RackLocationRepository rackLocationRepository;

    @Transactional(readOnly = true)
    public List<PutawayTaskResponse> listTasks(String status) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<WarehousePutawayTask> list;
        if (status != null && !status.isBlank()) {
            list = taskRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, status.toUpperCase());
        } else {
            list = taskRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId);
        }
        return list.stream().map(PutawayTaskResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public PutawayTaskResponse getTask(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WarehousePutawayTask task = taskRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, id)
                .orElseThrow(() -> BusinessException.notFound("WarehousePutawayTask", id));
        return PutawayTaskResponse.from(task);
    }

    @Transactional
    public PutawayTaskResponse createTask(PutawayTaskRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Warehouse warehouse = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.getWarehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.getWarehouseId()));
        if (request.getLines() == null || request.getLines().isEmpty()) {
            throw new BusinessException("A putaway task requires at least one line", "PUTAWAY_LINES_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        String taskNo = "PTW-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();

        WarehousePutawayTask task = WarehousePutawayTask.builder()
                .taskNumber(taskNo)
                .goodsReceiptId(request.getGoodsReceiptId())
                .warehouseId(request.getWarehouseId())
                .sourceLocation(request.getSourceLocation() != null ? request.getSourceLocation() : "RECEIVING_DOCK")
                .assignedTo(request.getAssignedTo())
                .notes(request.getNotes())
                .status("PENDING")
                .lines(new ArrayList<>())
                .build();
        task.setOrgId(orgId);

        for (PutawayTaskRequest.PutawayLineRequest lr : request.getLines()) {
            itemRepository.findByIdAndOrgIdAndIsDeletedFalse(lr.getItemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", lr.getItemId()));
            validatePositiveQuantity(lr.getQuantity());
            if (lr.getSuggestedRackId() != null) {
                requireRackInWarehouse(lr.getSuggestedRackId(), warehouse, orgId);
            }

            WarehousePutawayLine line = WarehousePutawayLine.builder()
                    .task(task)
                    .itemId(lr.getItemId())
                    .batchNumber(lr.getBatchNumber())
                    .quantity(lr.getQuantity())
                    .suggestedRackId(lr.getSuggestedRackId())
                    .status("PENDING")
                    .build();
            task.getLines().add(line);
        }

        WarehousePutawayTask saved = taskRepository.save(task);
        log.info("Created putaway task [{}] with [{}] lines for org [{}]", taskNo, task.getLines().size(), orgId);
        return PutawayTaskResponse.from(saved);
    }

    @Transactional
    public PutawayTaskResponse confirmLine(UUID taskId, UUID lineId, PutawayLineConfirmRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        WarehousePutawayTask task = taskRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, taskId)
                .orElseThrow(() -> BusinessException.notFound("WarehousePutawayTask", taskId));

        WarehousePutawayLine line = task.getLines().stream()
                .filter(l -> l.getId().equals(lineId))
                .findFirst()
                .orElseThrow(() -> BusinessException.notFound("WarehousePutawayLine", lineId));

        if (!"PENDING".equals(line.getStatus())) {
            throw new BusinessException("Only pending putaway lines can be confirmed", "PUTAWAY_LINE_NOT_PENDING", HttpStatus.CONFLICT);
        }
        Warehouse warehouse = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(task.getWarehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", task.getWarehouseId()));
        requireRackInWarehouse(request.getConfirmedRackId(), warehouse, orgId);

        // The current inventory model has one default pick rack per item, not a
        // quantity-per-rack ledger. Putaway may set an empty default, but never
        // overwrites an established location from a partial physical task.
        Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(line.getItemId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Item", line.getItemId()));
        if (item.getRackLocationId() == null) {
            item.setRackLocationId(request.getConfirmedRackId());
            itemRepository.save(item);
        }

        line.setConfirmedRackId(request.getConfirmedRackId());
        line.setStatus("CONFIRMED");
        line.setConfirmedAt(Instant.now());
        line.setConfirmedBy(userId);
        lineRepository.save(line);

        // Update task status
        boolean allConfirmed = task.getLines().stream().allMatch(l -> "CONFIRMED".equals(l.getStatus()) || "SKIPPED".equals(l.getStatus()));
        if (allConfirmed) {
            task.setStatus("COMPLETED");
        } else {
            task.setStatus("IN_PROGRESS");
        }
        WarehousePutawayTask saved = taskRepository.save(task);

        log.info("Confirmed putaway line [{}] in task [{}], task status [{}]", lineId, task.getTaskNumber(), task.getStatus());
        return PutawayTaskResponse.from(saved);
    }

    private void validatePositiveQuantity(java.math.BigDecimal quantity) {
        if (quantity == null || quantity.signum() <= 0) {
            throw new BusinessException("Putaway quantity must be positive", "PUTAWAY_INVALID_QUANTITY", HttpStatus.BAD_REQUEST);
        }
    }

    private RackLocation requireRackInWarehouse(UUID rackId, Warehouse warehouse, UUID orgId) {
        RackLocation rack = rackLocationRepository.findByIdAndOrgIdAndIsDeletedFalse(rackId, orgId)
                .orElseThrow(() -> BusinessException.notFound("RackLocation", rackId));
        if (!rack.isActive() || !warehouse.getId().equals(rack.getWarehouseId())) {
            throw new BusinessException("Rack location must be active and belong to the task warehouse",
                    "PUTAWAY_RACK_WAREHOUSE_MISMATCH", HttpStatus.BAD_REQUEST);
        }
        return rack;
    }

    @Transactional
    public PutawayTaskResponse cancelTask(UUID taskId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        WarehousePutawayTask task = taskRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, taskId)
                .orElseThrow(() -> BusinessException.notFound("WarehousePutawayTask", taskId));

        task.setStatus("CANCELLED");
        WarehousePutawayTask saved = taskRepository.save(task);
        log.info("Cancelled putaway task [{}]", task.getTaskNumber());
        return PutawayTaskResponse.from(saved);
    }
}
