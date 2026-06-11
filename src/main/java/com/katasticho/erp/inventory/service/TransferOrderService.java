package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.*;
import com.katasticho.erp.inventory.entity.*;
import com.katasticho.erp.inventory.repository.*;
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
public class TransferOrderService {

    private final TransferOrderRepository transferOrderRepository;
    private final WarehouseRepository warehouseRepository;
    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final StockBatchRepository batchRepository;
    private final StockMovementRepository stockMovementRepository;
    private final InventoryService inventoryService;

    @Transactional
    public TransferOrderResponse create(CreateTransferOrderRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (request.fromWarehouseId().equals(request.toWarehouseId())) {
            throw new BusinessException("Source and destination warehouse must be different",
                    "TO_SAME_WAREHOUSE", HttpStatus.BAD_REQUEST);
        }

        Warehouse fromWh = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.fromWarehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.fromWarehouseId()));
        Warehouse toWh = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.toWarehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.toWarehouseId()));

        LocalDate transferDate = request.transferDate() != null ? request.transferDate() : LocalDate.now();
        String number = generateNumber(orgId);

        TransferOrder to = TransferOrder.builder()
                .transferNumber(number)
                .fromWarehouseId(fromWh.getId())
                .toWarehouseId(toWh.getId())
                .transferDate(transferDate)
                .notes(request.notes())
                .build();

        for (TransferOrderLineRequest lr : request.lines()) {
            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(lr.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", lr.itemId()));

            if (lr.quantity() == null || lr.quantity().compareTo(BigDecimal.ZERO) <= 0) {
                throw new BusinessException("Transfer quantity must be positive for " + item.getName(),
                        "TO_INVALID_QUANTITY", HttpStatus.BAD_REQUEST);
            }

            TransferOrderLine line = TransferOrderLine.builder()
                    .itemId(item.getId())
                    .batchId(lr.batchId())
                    .quantity(lr.quantity())
                    .notes(lr.notes())
                    .build();
            to.addLine(line);
        }

        to = transferOrderRepository.save(to);
        log.info("Transfer order {} created: {} → {}", number, fromWh.getName(), toWh.getName());
        return toResponse(to, fromWh.getName(), toWh.getName());
    }

    @Transactional(readOnly = true)
    public TransferOrderResponse get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrder to = findOrThrow(id, orgId);
        return toResponseWithNames(to);
    }

    @Transactional(readOnly = true)
    public Page<TransferOrderResponse> list(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<UUID, String> whNames = warehouseRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId)
                .stream().collect(Collectors.toMap(Warehouse::getId, Warehouse::getName));
        return transferOrderRepository
                .findByOrgIdAndIsDeletedFalseOrderByTransferDateDesc(orgId, pageable)
                .map(to -> toResponse(to, whNames.get(to.getFromWarehouseId()), whNames.get(to.getToWarehouseId())));
    }

    @Transactional
    public TransferOrderResponse ship(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        TransferOrder to = findOrThrow(id, orgId);

        if (!"DRAFT".equals(to.getStatus())) {
            throw new BusinessException("Only DRAFT transfer orders can be shipped",
                    "TO_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        for (TransferOrderLine line : to.getLines()) {
            validateStock(orgId, line, to.getFromWarehouseId());

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    to.getFromWarehouseId(),
                    MovementType.TRANSFER_OUT,
                    line.getQuantity().negate(),
                    null,
                    to.getTransferDate(),
                    ReferenceType.STOCK_TRANSFER,
                    to.getId(),
                    to.getTransferNumber(),
                    "Transfer out to " + to.getToWarehouseId(),
                    line.getBatchId()
            ));
        }

        to.setStatus("IN_TRANSIT");
        to.setShippedAt(Instant.now());
        to.setShippedBy(userId);
        transferOrderRepository.save(to);

        log.info("Transfer order {} shipped", to.getTransferNumber());
        return toResponseWithNames(to);
    }

    @Transactional
    public TransferOrderResponse receive(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        TransferOrder to = findOrThrow(id, orgId);

        if (!"IN_TRANSIT".equals(to.getStatus())) {
            throw new BusinessException("Only IN_TRANSIT transfer orders can be received",
                    "TO_NOT_IN_TRANSIT", HttpStatus.BAD_REQUEST);
        }

        // Carry the cost the TRANSFER_OUT legs recorded at ship time. Under
        // FIFO the out leg drained lots at the true blended cost; receiving at
        // any other basis (e.g. latest purchase price) would create or destroy
        // inventory value on a pure warehouse move.
        Map<UUID, BigDecimal> shippedUnitCost = new HashMap<>();
        for (StockMovementRepository.ItemCostRow row : stockMovementRepository
                .sumCostAndQtyByReferences(orgId, ReferenceType.STOCK_TRANSFER,
                        List.of(to.getId()), MovementType.TRANSFER_OUT)) {
            if (row.getTotalQty() != null && row.getTotalQty().signum() > 0) {
                shippedUnitCost.put(row.getItemId(),
                        row.getTotalCost().divide(row.getTotalQty(), 4, java.math.RoundingMode.HALF_UP));
            }
        }

        for (TransferOrderLine line : to.getLines()) {
            BigDecimal qty = line.getQuantity();

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    to.getToWarehouseId(),
                    MovementType.TRANSFER_IN,
                    qty,
                    shippedUnitCost.get(line.getItemId()),
                    LocalDate.now(),
                    ReferenceType.STOCK_TRANSFER,
                    to.getId(),
                    to.getTransferNumber(),
                    "Transfer in from " + to.getFromWarehouseId(),
                    line.getBatchId()
            ));

            line.setReceivedQuantity(qty);
        }

        to.setStatus("RECEIVED");
        to.setReceivedAt(Instant.now());
        to.setReceivedBy(userId);
        transferOrderRepository.save(to);

        log.info("Transfer order {} received", to.getTransferNumber());
        return toResponseWithNames(to);
    }

    @Transactional
    public void cancel(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        TransferOrder to = findOrThrow(id, orgId);

        if ("RECEIVED".equals(to.getStatus())) {
            throw new BusinessException("Cannot cancel a received transfer order",
                    "TO_ALREADY_RECEIVED", HttpStatus.BAD_REQUEST);
        }

        if ("IN_TRANSIT".equals(to.getStatus())) {
            for (TransferOrderLine line : to.getLines()) {
                inventoryService.recordMovement(new StockMovementRequest(
                        line.getItemId(),
                        to.getFromWarehouseId(),
                        MovementType.TRANSFER_IN,
                        line.getQuantity(),
                        null,
                        LocalDate.now(),
                        ReferenceType.STOCK_TRANSFER,
                        to.getId(),
                        to.getTransferNumber(),
                        "Transfer cancelled — stock returned",
                        line.getBatchId()
                ));
            }
        }

        to.setStatus("CANCELLED");
        transferOrderRepository.save(to);
        log.info("Transfer order {} cancelled", to.getTransferNumber());
    }

    private void validateStock(UUID orgId, TransferOrderLine line, UUID warehouseId) {
        BigDecimal onHand = stockBalanceRepository
                .findByOrgIdAndItemIdAndWarehouseId(orgId, line.getItemId(), warehouseId)
                .map(StockBalance::getQuantityOnHand)
                .orElse(BigDecimal.ZERO);
        if (onHand.compareTo(line.getQuantity()) < 0) {
            String itemName = itemRepository.findById(line.getItemId())
                    .map(Item::getName).orElse("Unknown");
            throw new BusinessException(
                    "Insufficient stock for '" + itemName + "': available " + onHand + ", required " + line.getQuantity(),
                    "TO_INSUFFICIENT_STOCK", HttpStatus.BAD_REQUEST);
        }
    }

    private TransferOrder findOrThrow(UUID id, UUID orgId) {
        return transferOrderRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Transfer Order", id));
    }

    private String generateNumber(UUID orgId) {
        String prefix = "TO-" + LocalDate.now().getYear();
        int seq = transferOrderRepository.nextSequence(orgId, prefix);
        return String.format("%s-%06d", prefix, seq);
    }

    private TransferOrderResponse toResponseWithNames(TransferOrder to) {
        String fromName = warehouseRepository.findById(to.getFromWarehouseId())
                .map(Warehouse::getName).orElse(null);
        String toName = warehouseRepository.findById(to.getToWarehouseId())
                .map(Warehouse::getName).orElse(null);
        return toResponse(to, fromName, toName);
    }

    private TransferOrderResponse toResponse(TransferOrder to, String fromName, String toName) {
        UUID orgId = to.getOrgId() != null ? to.getOrgId() : TenantContext.getCurrentOrgId();
        Map<UUID, Item> items = to.getLines().isEmpty() ? Map.of() :
                itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(
                        orgId, to.getLines().stream().map(TransferOrderLine::getItemId).toList()
                ).stream().collect(Collectors.toMap(Item::getId, i -> i));

        Map<UUID, StockBatch> batches = new HashMap<>();
        List<UUID> batchIds = to.getLines().stream()
                .map(TransferOrderLine::getBatchId).filter(Objects::nonNull).toList();
        if (!batchIds.isEmpty()) {
            batchRepository.findAllById(batchIds).forEach(b -> batches.put(b.getId(), b));
        }

        List<TransferOrderResponse.TransferOrderLineResponse> lineResponses = to.getLines().stream()
                .map(l -> {
                    Item item = items.get(l.getItemId());
                    StockBatch batch = l.getBatchId() != null ? batches.get(l.getBatchId()) : null;
                    return new TransferOrderResponse.TransferOrderLineResponse(
                            l.getId(),
                            l.getItemId(),
                            item != null ? item.getName() : null,
                            item != null ? item.getSku() : null,
                            l.getBatchId(),
                            batch != null ? batch.getBatchNumber() : null,
                            l.getQuantity(),
                            l.getReceivedQuantity(),
                            l.getNotes()
                    );
                }).toList();

        return new TransferOrderResponse(
                to.getId(),
                to.getTransferNumber(),
                to.getFromWarehouseId(), fromName,
                to.getToWarehouseId(), toName,
                to.getTransferDate(),
                to.getStatus(),
                to.getNotes(),
                to.getShippedAt(),
                to.getReceivedAt(),
                to.getLines().size(),
                lineResponses,
                to.getCreatedAt()
        );
    }
}
