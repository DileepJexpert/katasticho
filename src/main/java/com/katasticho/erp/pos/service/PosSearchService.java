package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.pos.dto.PosSearchResult;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import com.katasticho.erp.tax.entity.TaxGroup;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Optimized POS item search.
 * <p>
 * Search priority: exact barcode > exact SKU > name prefix > name contains.
 * Results are cached in Redis for 5 minutes per (org, query) pair.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PosSearchService {

    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final StockBatchRepository batchRepository;
    private final WarehouseRepository warehouseRepository;
    private final TaxGroupRepository taxGroupRepository;

    @Transactional(readOnly = true)
    @Cacheable(value = "pos-search", key = "#orgId + ':' + #query + ':' + #warehouseId",
            unless = "#result.isEmpty()")
    public List<PosSearchResult> search(UUID orgId, String query, UUID warehouseId, int limit) {
        if (query == null || query.isBlank()) return List.of();

        String q = query.trim();
        List<Item> candidates = new ArrayList<>();

        // 1. Exact barcode match
        itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, q)
                .ifPresent(candidates::add);

        // 2. Exact SKU match
        if (candidates.isEmpty()) {
            itemRepository.findByOrgIdAndSkuAndIsDeletedFalse(orgId, q)
                    .ifPresent(candidates::add);
        }

        // 3. Name/SKU contains search (broader)
        if (candidates.isEmpty()) {
            Page<Item> searchPage = itemRepository.search(orgId, q, PageRequest.of(0, limit));
            candidates.addAll(searchPage.getContent());
        }

        // Filter to active items only, cap at limit
        List<Item> items = candidates.stream()
                .filter(Item::isActive)
                .distinct()
                .limit(limit)
                .toList();

        if (items.isEmpty()) return List.of();

        // Resolve effective warehouse
        UUID effectiveWarehouseId = warehouseId;
        if (effectiveWarehouseId == null) {
            effectiveWarehouseId = warehouseRepository
                    .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                    .map(Warehouse::getId)
                    .orElse(null);
        }

        // Pre-load stock balances for all matched items
        final UUID whId = effectiveWarehouseId;
        Map<UUID, StockBalance> balanceMap = whId == null ? Map.of()
                : items.stream()
                .map(item -> stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, item.getId(), whId))
                .filter(Optional::isPresent)
                .map(Optional::get)
                .collect(Collectors.toMap(StockBalance::getItemId, b -> b));

        // Pre-load tax group names
        Set<UUID> taxGroupIds = items.stream()
                .map(Item::getDefaultTaxGroupId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, String> taxGroupNames = taxGroupIds.isEmpty() ? Map.of()
                : taxGroupRepository.findAllById(taxGroupIds).stream()
                .collect(Collectors.toMap(TaxGroup::getId, TaxGroup::getName));

        // Build results
        return items.stream().map(item -> {
            StockBalance balance = balanceMap.get(item.getId());
            BigDecimal currentStock = balance != null ? balance.getQuantityOnHand() : BigDecimal.ZERO;

            // FEFO batch for batch-tracked items
            UUID batchId = null;
            java.time.LocalDate batchExpiry = null;
            if (item.isTrackBatches() && whId != null) {
                List<StockBatch> batches = batchRepository.findFefoBatches(orgId, item.getId(), whId);
                if (!batches.isEmpty()) {
                    StockBatch nearest = batches.get(0);
                    batchId = nearest.getId();
                    batchExpiry = nearest.getExpiryDate();
                }
            }

            return new PosSearchResult(
                    item.getId(),
                    item.getName(),
                    item.getSku(),
                    item.getBarcode(),
                    item.getSalePrice(),
                    item.getMrp(),
                    item.getPurchasePrice(),
                    item.getDefaultTaxGroupId(),
                    item.getDefaultTaxGroupId() != null
                            ? taxGroupNames.get(item.getDefaultTaxGroupId()) : null,
                    item.getHsnCode(),
                    item.getUnitOfMeasure(),
                    currentStock,
                    item.isWeightBasedBilling(),
                    batchId,
                    batchExpiry);
        }).toList();
    }
}
