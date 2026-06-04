package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.*;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.*;
import com.katasticho.erp.sales.entity.SalesOrder;
import com.katasticho.erp.sales.entity.SalesOrderLine;
import com.katasticho.erp.sales.repository.SalesOrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class PicklistService {

    private final PicklistRepository picklistRepository;
    private final SalesOrderRepository salesOrderRepository;
    private final WarehouseRepository warehouseRepository;
    private final ItemRepository itemRepository;
    private final StockBatchRepository batchRepository;
    private final RackLocationRepository rackLocationRepository;

    @Transactional
    public PicklistResponse create(CreatePicklistRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesOrder so = salesOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(request.salesOrderId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Sales Order", request.salesOrderId()));

        if (!List.of("CONFIRMED", "PARTIALLY_SHIPPED", "BACKORDER").contains(so.getStatus())) {
            throw new BusinessException("Sales order must be CONFIRMED, PARTIALLY_SHIPPED, or BACKORDER to generate a picklist",
                    "PL_INVALID_SO_STATUS", HttpStatus.BAD_REQUEST);
        }

        Warehouse wh = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.warehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.warehouseId()));

        Map<UUID, SalesOrderLine> soLineMap = so.getLines().stream()
                .collect(Collectors.toMap(SalesOrderLine::getId, l -> l));

        String number = generateNumber(orgId);
        Picklist pl = Picklist.builder()
                .picklistNumber(number)
                .salesOrderId(so.getId())
                .warehouseId(wh.getId())
                .assignedTo(request.assignedTo())
                .notes(request.notes())
                .build();

        for (PicklistLineRequest lr : request.lines()) {
            SalesOrderLine soLine = soLineMap.get(lr.salesOrderLineId());
            if (soLine == null) {
                throw new BusinessException("Sales order line not found: " + lr.salesOrderLineId(),
                        "PL_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST);
            }

            BigDecimal remaining = soLine.getQuantity()
                    .subtract(soLine.getQuantityShipped())
                    .subtract(soLine.getQuantityBackordered());
            if (lr.requiredQuantity().compareTo(remaining) > 0) {
                throw new BusinessException("Required quantity exceeds remaining shippable quantity for line",
                        "PL_EXCEEDS_REMAINING", HttpStatus.BAD_REQUEST);
            }

            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(soLine.getItemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", soLine.getItemId()));

            UUID rackLocationId = item.getRackLocationId();

            PicklistLine line = PicklistLine.builder()
                    .salesOrderLineId(soLine.getId())
                    .itemId(item.getId())
                    .requiredQuantity(lr.requiredQuantity())
                    .batchId(lr.batchId())
                    .rackLocationId(rackLocationId)
                    .notes(lr.notes())
                    .build();
            pl.addLine(line);
        }

        pl = picklistRepository.save(pl);
        log.info("Picklist {} created for SO {} with {} lines", number, so.getSalesorderNumber(), pl.getLines().size());
        return toResponse(pl, so.getSalesorderNumber(), wh.getName());
    }

    @Transactional(readOnly = true)
    public PicklistResponse get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Picklist pl = findOrThrow(id, orgId);
        return toResponseWithNames(pl);
    }

    @Transactional(readOnly = true)
    public Page<PicklistResponse> list(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return picklistRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, pageable)
                .map(this::toResponseWithNames);
    }

    @Transactional(readOnly = true)
    public List<PicklistResponse> listBySalesOrder(UUID salesOrderId) {
        return picklistRepository.findBySalesOrderIdAndIsDeletedFalse(salesOrderId)
                .stream().map(this::toResponseWithNames).toList();
    }

    @Transactional
    public PicklistResponse startPicking(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Picklist pl = findOrThrow(id, orgId);

        if (!"PENDING".equals(pl.getStatus())) {
            throw new BusinessException("Only PENDING picklists can be started",
                    "PL_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }

        pl.setStatus("IN_PROGRESS");
        pl.setStartedAt(Instant.now());
        picklistRepository.save(pl);
        log.info("Picklist {} started", pl.getPicklistNumber());
        return toResponseWithNames(pl);
    }

    @Transactional
    public PicklistResponse updatePickedQuantities(UUID id, UpdatePicklistLineRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Picklist pl = findOrThrow(id, orgId);

        if (!"IN_PROGRESS".equals(pl.getStatus())) {
            throw new BusinessException("Only IN_PROGRESS picklists can be updated",
                    "PL_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        Map<UUID, PicklistLine> lineMap = pl.getLines().stream()
                .collect(Collectors.toMap(PicklistLine::getId, l -> l));

        for (UpdatePicklistLineRequest.PickedLineEntry entry : request.lines()) {
            PicklistLine line = lineMap.get(entry.lineId());
            if (line == null) {
                throw new BusinessException("Picklist line not found: " + entry.lineId(),
                        "PL_LINE_NOT_FOUND", HttpStatus.BAD_REQUEST);
            }
            if (entry.pickedQuantity().compareTo(BigDecimal.ZERO) < 0) {
                throw new BusinessException("Picked quantity cannot be negative",
                        "PL_NEGATIVE_PICKED", HttpStatus.BAD_REQUEST);
            }
            line.setPickedQuantity(entry.pickedQuantity());
            if (entry.batchId() != null) {
                line.setBatchId(entry.batchId());
            }
            if (entry.notes() != null) {
                line.setNotes(entry.notes());
            }
        }

        picklistRepository.save(pl);
        return toResponseWithNames(pl);
    }

    @Transactional
    public PicklistResponse complete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Picklist pl = findOrThrow(id, orgId);

        if (!"IN_PROGRESS".equals(pl.getStatus())) {
            throw new BusinessException("Only IN_PROGRESS picklists can be completed",
                    "PL_NOT_IN_PROGRESS", HttpStatus.BAD_REQUEST);
        }

        pl.setStatus("COMPLETED");
        pl.setCompletedAt(Instant.now());
        picklistRepository.save(pl);
        log.info("Picklist {} completed", pl.getPicklistNumber());
        return toResponseWithNames(pl);
    }

    @Transactional
    public void cancel(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Picklist pl = findOrThrow(id, orgId);

        if ("COMPLETED".equals(pl.getStatus())) {
            throw new BusinessException("Cannot cancel a completed picklist",
                    "PL_ALREADY_COMPLETED", HttpStatus.BAD_REQUEST);
        }

        pl.setStatus("CANCELLED");
        picklistRepository.save(pl);
        log.info("Picklist {} cancelled", pl.getPicklistNumber());
    }

    private Picklist findOrThrow(UUID id, UUID orgId) {
        return picklistRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Picklist", id));
    }

    private String generateNumber(UUID orgId) {
        String prefix = "PL-" + LocalDate.now().getYear();
        int seq = picklistRepository.nextSequence(orgId, prefix);
        return String.format("%s-%06d", prefix, seq);
    }

    private PicklistResponse toResponseWithNames(Picklist pl) {
        String soNumber = salesOrderRepository.findById(pl.getSalesOrderId())
                .map(SalesOrder::getSalesorderNumber).orElse(null);
        String whName = warehouseRepository.findById(pl.getWarehouseId())
                .map(Warehouse::getName).orElse(null);
        return toResponse(pl, soNumber, whName);
    }

    private PicklistResponse toResponse(Picklist pl, String soNumber, String whName) {
        UUID orgId = pl.getOrgId() != null ? pl.getOrgId() : TenantContext.getCurrentOrgId();

        Map<UUID, Item> items = pl.getLines().isEmpty() ? Map.of() :
                itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(
                        orgId, pl.getLines().stream().map(PicklistLine::getItemId).toList()
                ).stream().collect(Collectors.toMap(Item::getId, i -> i));

        Map<UUID, StockBatch> batches = new HashMap<>();
        List<UUID> batchIds = pl.getLines().stream()
                .map(PicklistLine::getBatchId).filter(Objects::nonNull).toList();
        if (!batchIds.isEmpty()) {
            batchRepository.findAllById(batchIds).forEach(b -> batches.put(b.getId(), b));
        }

        Map<UUID, RackLocation> racks = new HashMap<>();
        List<UUID> rackIds = pl.getLines().stream()
                .map(PicklistLine::getRackLocationId).filter(Objects::nonNull).toList();
        if (!rackIds.isEmpty()) {
            rackLocationRepository.findAllById(rackIds).forEach(r -> racks.put(r.getId(), r));
        }

        List<PicklistResponse.PicklistLineResponse> lineResponses = pl.getLines().stream()
                .map(l -> {
                    Item item = items.get(l.getItemId());
                    StockBatch batch = l.getBatchId() != null ? batches.get(l.getBatchId()) : null;
                    RackLocation rack = l.getRackLocationId() != null ? racks.get(l.getRackLocationId()) : null;
                    return new PicklistResponse.PicklistLineResponse(
                            l.getId(),
                            l.getSalesOrderLineId(),
                            l.getItemId(),
                            item != null ? item.getName() : null,
                            item != null ? item.getSku() : null,
                            l.getRequiredQuantity(),
                            l.getPickedQuantity(),
                            l.getBatchId(),
                            batch != null ? batch.getBatchNumber() : null,
                            l.getRackLocationId(),
                            rack != null ? rack.getCode() : null,
                            l.getNotes()
                    );
                }).toList();

        int pickedCount = (int) pl.getLines().stream()
                .filter(l -> l.getPickedQuantity().compareTo(BigDecimal.ZERO) > 0).count();

        return new PicklistResponse(
                pl.getId(),
                pl.getPicklistNumber(),
                pl.getSalesOrderId(),
                soNumber,
                pl.getWarehouseId(),
                whName,
                pl.getStatus(),
                pl.getAssignedTo(),
                pl.getNotes(),
                pl.getStartedAt(),
                pl.getCompletedAt(),
                pl.getLines().size(),
                pickedCount,
                lineResponses,
                pl.getCreatedAt()
        );
    }
}
