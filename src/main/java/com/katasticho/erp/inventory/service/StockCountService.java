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
public class StockCountService {

    private final StockCountRepository stockCountRepository;
    private final StockCountLineRepository lineRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final WarehouseRepository warehouseRepository;
    private final ItemRepository itemRepository;
    private final InventoryService inventoryService;

    @Transactional
    public StockCountResponse create(CreateStockCountRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Warehouse warehouse = warehouseRepository.findByIdAndOrgIdAndIsDeletedFalse(request.warehouseId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Warehouse", request.warehouseId()));

        LocalDate countDate = request.countDate() != null ? request.countDate() : LocalDate.now();
        String countNumber = generateNumber(orgId);

        StockCount sc = StockCount.builder()
                .warehouseId(warehouse.getId())
                .countNumber(countNumber)
                .countDate(countDate)
                .notes(request.notes())
                .build();

        Set<UUID> seenItems = new HashSet<>();
        for (StockCountLineRequest lr : request.lines()) {
            if (!seenItems.add(lr.itemId())) {
                throw new BusinessException("Duplicate item in stock count",
                        "SC_DUPLICATE_ITEM", HttpStatus.BAD_REQUEST);
            }

            Item item = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(lr.itemId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("Item", lr.itemId()));

            BigDecimal systemQty = stockBalanceRepository
                    .findByOrgIdAndItemIdAndWarehouseId(orgId, item.getId(), warehouse.getId())
                    .map(StockBalance::getQuantityOnHand)
                    .orElse(BigDecimal.ZERO);

            BigDecimal variance = lr.countedQuantity().subtract(systemQty);

            StockCountLine line = StockCountLine.builder()
                    .itemId(item.getId())
                    .expectedQuantity(systemQty)
                    .countedQuantity(lr.countedQuantity())
                    .variance(variance)
                    .notes(lr.notes())
                    .build();
            sc.addLine(line);
        }

        sc = stockCountRepository.save(sc);
        log.info("Stock count {} created with {} lines for warehouse {}",
                countNumber, sc.getLines().size(), warehouse.getName());
        return toResponse(sc, warehouse.getName());
    }

    @Transactional(readOnly = true)
    public StockCountResponse get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        StockCount sc = findOrThrow(id, orgId);
        String whName = warehouseRepository.findById(sc.getWarehouseId())
                .map(Warehouse::getName).orElse(null);
        return toResponse(sc, whName);
    }

    @Transactional(readOnly = true)
    public Page<StockCountResponse> list(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<UUID, String> whNames = warehouseRepository.findByOrgIdAndIsDeletedFalseOrderByName(orgId)
                .stream().collect(Collectors.toMap(Warehouse::getId, Warehouse::getName));
        return stockCountRepository
                .findByOrgIdAndIsDeletedFalseOrderByCountDateDesc(orgId, pageable)
                .map(sc -> toResponse(sc, whNames.get(sc.getWarehouseId())));
    }

    @Transactional
    public StockCountResponse post(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        StockCount sc = findOrThrow(id, orgId);

        if (!"DRAFT".equals(sc.getStatus())) {
            throw new BusinessException("Only DRAFT stock counts can be posted",
                    "SC_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        if (sc.getLines().isEmpty()) {
            throw new BusinessException("Stock count has no lines",
                    "SC_NO_LINES", HttpStatus.BAD_REQUEST);
        }

        for (StockCountLine line : sc.getLines()) {
            if (line.getVariance().compareTo(BigDecimal.ZERO) == 0) continue;

            MovementType type = line.getVariance().compareTo(BigDecimal.ZERO) > 0
                    ? MovementType.STOCK_COUNT
                    : MovementType.STOCK_COUNT;

            inventoryService.recordMovement(new StockMovementRequest(
                    line.getItemId(),
                    sc.getWarehouseId(),
                    type,
                    line.getVariance(),
                    null,
                    sc.getCountDate(),
                    ReferenceType.STOCK_COUNT,
                    sc.getId(),
                    sc.getCountNumber(),
                    "Stock count variance: expected " + line.getExpectedQuantity()
                            + ", counted " + line.getCountedQuantity()
            ));
        }

        sc.setStatus("POSTED");
        sc.setPostedAt(Instant.now());
        sc.setPostedBy(userId);
        stockCountRepository.save(sc);

        String whName = warehouseRepository.findById(sc.getWarehouseId())
                .map(Warehouse::getName).orElse(null);
        log.info("Stock count {} posted — {} variance movements recorded",
                sc.getCountNumber(), sc.getLines().stream()
                        .filter(l -> l.getVariance().compareTo(BigDecimal.ZERO) != 0).count());
        return toResponse(sc, whName);
    }

    @Transactional
    public void cancel(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        StockCount sc = findOrThrow(id, orgId);

        if (!"DRAFT".equals(sc.getStatus())) {
            throw new BusinessException("Only DRAFT stock counts can be cancelled",
                    "SC_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }

        sc.setStatus("CANCELLED");
        stockCountRepository.save(sc);
        log.info("Stock count {} cancelled", sc.getCountNumber());
    }

    private StockCount findOrThrow(UUID id, UUID orgId) {
        return stockCountRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Stock Count", id));
    }

    private String generateNumber(UUID orgId) {
        String prefix = "SC-" + LocalDate.now().getYear();
        int seq = stockCountRepository.nextSequence(orgId, prefix);
        return String.format("%s-%06d", prefix, seq);
    }

    private StockCountResponse toResponse(StockCount sc, String warehouseName) {
        UUID orgId = sc.getOrgId() != null ? sc.getOrgId() : TenantContext.getCurrentOrgId();
        Map<UUID, Item> items = sc.getLines().isEmpty() ? Map.of() :
                itemRepository.findByOrgIdAndIsDeletedFalseAndIdIn(
                        orgId,
                        sc.getLines().stream().map(StockCountLine::getItemId).toList()
                ).stream().collect(Collectors.toMap(Item::getId, i -> i));

        List<StockCountResponse.StockCountLineResponse> lineResponses = sc.getLines().stream()
                .map(l -> {
                    Item item = items.get(l.getItemId());
                    return new StockCountResponse.StockCountLineResponse(
                            l.getId(),
                            l.getItemId(),
                            item != null ? item.getName() : null,
                            item != null ? item.getSku() : null,
                            l.getExpectedQuantity(),
                            l.getCountedQuantity(),
                            l.getVariance(),
                            l.getNotes()
                    );
                }).toList();

        int varianceCount = (int) sc.getLines().stream()
                .filter(l -> l.getVariance().compareTo(BigDecimal.ZERO) != 0).count();

        return new StockCountResponse(
                sc.getId(),
                sc.getCountNumber(),
                sc.getWarehouseId(),
                warehouseName,
                sc.getCountDate(),
                sc.getStatus(),
                sc.getNotes(),
                sc.getPostedAt(),
                sc.getLines().size(),
                varianceCount,
                lineResponses,
                sc.getCreatedAt()
        );
    }
}
