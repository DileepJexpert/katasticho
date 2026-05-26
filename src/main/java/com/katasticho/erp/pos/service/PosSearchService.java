package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.entity.RackLocation;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.RackLocationRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.dto.DiscountThresholds;
import com.katasticho.erp.pos.dto.PosSearchResult;
import com.katasticho.erp.tax.TaxEngine;
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
    private final RackLocationRepository rackLocationRepository;
    private final WarehouseRepository warehouseRepository;
    private final TaxGroupRepository taxGroupRepository;
    private final OrganisationRepository organisationRepository;
    private final TaxEngine taxEngine;

    @Transactional(readOnly = true)
    @Cacheable(value = "pos-search", key = "#orgId + ':' + #query + ':' + #warehouseId",
            unless = "#result.isEmpty()")
    public List<PosSearchResult> search(UUID orgId, String query, UUID warehouseId, int limit) {
        if (query == null || query.isBlank()) return List.of();

        String q = query.trim();
        List<Item> candidates = new ArrayList<>();

        // 1. Exact barcode match (raw value first, then GS1-extracted)
        itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, q)
                .ifPresent(candidates::add);

        if (candidates.isEmpty()) {
            String extracted = extractGs1Barcode(q);
            if (extracted != null) {
                itemRepository.findByOrgIdAndBarcodeAndIsDeletedFalse(orgId, extracted)
                        .ifPresent(candidates::add);
            }
        }

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

        // Resolve tax group for items missing defaultTaxGroupId but having gstRate
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        String stateCode = org != null ? org.getStateCode() : null;

        Map<UUID, UUID> resolvedTaxGroupIds = new HashMap<>();
        for (Item item : items) {
            UUID tgId = item.getDefaultTaxGroupId();
            if (tgId == null && item.getGstRate() != null
                    && item.getGstRate().compareTo(BigDecimal.ZERO) > 0
                    && stateCode != null) {
                tgId = taxEngine.resolveGroupId(orgId, item.getGstRate(),
                        stateCode, stateCode).orElse(null);
            }
            if (tgId != null) {
                resolvedTaxGroupIds.put(item.getId(), tgId);
            }
        }

        // Pre-load tax group names
        Set<UUID> taxGroupIds = new HashSet<>(resolvedTaxGroupIds.values());
        Map<UUID, String> taxGroupNames = taxGroupIds.isEmpty() ? Map.of()
                : taxGroupRepository.findAllById(taxGroupIds).stream()
                .collect(Collectors.toMap(TaxGroup::getId, TaxGroup::getName));
        Set<UUID> rackIds = items.stream()
                .map(Item::getRackLocationId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<UUID, String> rackCodes = rackIds.isEmpty() ? Map.of()
                : rackLocationRepository.findAllById(rackIds).stream()
                .collect(Collectors.toMap(RackLocation::getId, RackLocation::getCode));

        // Build results
        return items.stream().map(item -> {
            StockBalance balance = balanceMap.get(item.getId());
            BigDecimal currentStock = balance != null ? balance.getQuantityOnHand() : BigDecimal.ZERO;

            // FEFO batch for batch-tracked items
            UUID batchId = null;
            java.time.LocalDate batchExpiry = null;
            String batchNumber = null;
            if (item.isTrackBatches() && whId != null) {
                List<StockBatch> batches = batchRepository.findFefoBatches(orgId, item.getId(), whId);
                if (!batches.isEmpty()) {
                    StockBatch nearest = batches.get(0);
                    batchId = nearest.getId();
                    batchExpiry = nearest.getExpiryDate();
                    batchNumber = nearest.getBatchNumber();
                }
            }

            BigDecimal effectiveRate = item.getSalePrice();
            if ((effectiveRate == null || effectiveRate.compareTo(BigDecimal.ZERO) <= 0)
                    && item.getMrp() != null && item.getMrp().compareTo(BigDecimal.ZERO) > 0) {
                effectiveRate = item.getMrp();
            }

            DiscountThresholds thresholds = DiscountThresholds.compute(
                    effectiveRate != null ? effectiveRate.doubleValue() : 0,
                    item.getPurchasePrice() != null ? item.getPurchasePrice().doubleValue() : 0);

            UUID effectiveTaxGroupId = resolvedTaxGroupIds.get(item.getId());

            return new PosSearchResult(
                    item.getId(),
                    item.getName(),
                    item.getSku(),
                    item.getBarcode(),
                    effectiveRate,
                    item.getMrp(),
                    item.getPurchasePrice(),
                    effectiveTaxGroupId,
                    effectiveTaxGroupId != null
                            ? taxGroupNames.get(effectiveTaxGroupId) : null,
                    item.getHsnCode(),
                    item.getUnitOfMeasure(),
                    currentStock,
                    item.isWeightBasedBilling(),
                    batchId,
                    batchExpiry,
                    item.isTrackBatches(),
                    batchNumber,
                    thresholds,
                    item.isPrescriptionRequired(),
                    item.getDrugSchedule(),
                    item.getComposition(),
                    item.getManufacturer(),
                    rackCodes.get(item.getRackLocationId()));
        }).toList();
    }

    /**
     * Extract barcode from GS1 format (GS1-128, DataMatrix).
     * AI 01 = GTIN-14 (14 digits). Leading '0' in GTIN-14 is packaging indicator;
     * strip it to get EAN-13.
     */
    private static String extractGs1Barcode(String raw) {
        if (raw == null || raw.length() < 16) return null;
        if (!raw.startsWith("01")) return null;
        if (!raw.substring(2, 16).chars().allMatch(Character::isDigit)) return null;

        String gtin14 = raw.substring(2, 16);
        if (gtin14.charAt(0) == '0') {
            return gtin14.substring(1); // EAN-13
        }
        return gtin14;
    }
}
