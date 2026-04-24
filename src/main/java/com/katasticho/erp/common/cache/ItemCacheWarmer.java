package com.katasticho.erp.common.cache;

import com.katasticho.erp.common.cache.dto.CachedItemPrice;
import com.katasticho.erp.common.cache.dto.CachedPosItem;
import com.katasticho.erp.common.cache.dto.CachedStockBalance;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.tax.entity.TaxGroup;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
@Slf4j
public class ItemCacheWarmer {

    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final WarehouseRepository warehouseRepository;
    private final TaxGroupRepository taxGroupRepository;
    private final CacheService cacheService;

    private static final Duration ITEM_TTL = Duration.ofHours(12);
    private static final int PAGE_SIZE = 500;

    public int warmItemPrices(UUID orgId) {
        log.info("[CacheWarmer] Warming item prices for org={}", orgId);
        int count = 0;
        int page = 0;
        Page<Item> itemPage;

        do {
            itemPage = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, PageRequest.of(page, PAGE_SIZE));
            for (Item item : itemPage.getContent()) {
                CachedItemPrice cached = new CachedItemPrice(
                        item.getId(), item.getName(), item.getSku(), item.getBarcode(),
                        item.getSalePrice(), item.getPurchasePrice(), item.getMrp(),
                        item.getGstRate(), item.getDefaultTaxGroupId(),
                        item.getHsnCode(), item.getUnitOfMeasure(), item.isActive());
                cacheService.put(CacheKeys.itemPrice(orgId, item.getId()), cached, ITEM_TTL);
                count++;
            }
            page++;
        } while (itemPage.hasNext());

        log.info("[CacheWarmer] Warmed {} item prices for org={}", count, orgId);
        return count;
    }

    public int warmStockBalances(UUID orgId) {
        log.info("[CacheWarmer] Warming stock balances for org={}", orgId);
        int count = 0;

        UUID defaultWarehouseId = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(w -> w.getId()).orElse(null);

        if (defaultWarehouseId == null) {
            log.warn("[CacheWarmer] No default warehouse for org={}, skipping stock balance warm", orgId);
            return 0;
        }

        int page = 0;
        Page<Item> itemPage;

        do {
            itemPage = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, PageRequest.of(page, PAGE_SIZE));
            for (Item item : itemPage.getContent()) {
                if (!item.isTrackInventory()) continue;

                List<StockBalance> balances = stockBalanceRepository.findByOrgIdAndItemId(orgId, item.getId());
                for (StockBalance bal : balances) {
                    CachedStockBalance cached = new CachedStockBalance(
                            item.getId(), bal.getWarehouseId(),
                            bal.getQuantityOnHand(), bal.getReservedQty(),
                            bal.getAverageCost(), item.getReorderLevel());
                    cacheService.put(CacheKeys.stockBalance(orgId, item.getId(), bal.getWarehouseId()), cached, ITEM_TTL);
                    count++;
                }

                if (balances.isEmpty()) {
                    CachedStockBalance cached = new CachedStockBalance(
                            item.getId(), defaultWarehouseId,
                            BigDecimal.ZERO, BigDecimal.ZERO,
                            BigDecimal.ZERO, item.getReorderLevel());
                    cacheService.put(CacheKeys.stockBalance(orgId, item.getId(), defaultWarehouseId), cached, ITEM_TTL);
                    count++;
                }
            }
            page++;
        } while (itemPage.hasNext());

        log.info("[CacheWarmer] Warmed {} stock balance entries for org={}", count, orgId);
        return count;
    }

    public int warmPosItems(UUID orgId) {
        log.info("[CacheWarmer] Warming POS item search cache for org={}", orgId);

        UUID defaultWarehouseId = warehouseRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(w -> w.getId()).orElse(null);

        List<CachedPosItem> posItems = new ArrayList<>();
        int page = 0;
        Page<Item> itemPage;

        Set<UUID> allTaxGroupIds = new HashSet<>();

        do {
            itemPage = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, PageRequest.of(page, PAGE_SIZE));
            for (Item item : itemPage.getContent()) {
                if (item.getDefaultTaxGroupId() != null) {
                    allTaxGroupIds.add(item.getDefaultTaxGroupId());
                }
            }
            page++;
        } while (itemPage.hasNext());

        Map<UUID, String> taxGroupNames = allTaxGroupIds.isEmpty() ? Map.of()
                : taxGroupRepository.findAllById(allTaxGroupIds).stream()
                .collect(Collectors.toMap(TaxGroup::getId, TaxGroup::getName));

        page = 0;
        do {
            itemPage = itemRepository.findByOrgIdAndIsDeletedFalseAndActiveTrue(orgId, PageRequest.of(page, PAGE_SIZE));
            for (Item item : itemPage.getContent()) {
                BigDecimal currentStock = BigDecimal.ZERO;
                if (defaultWarehouseId != null && item.isTrackInventory()) {
                    currentStock = stockBalanceRepository
                            .findByOrgIdAndItemIdAndWarehouseId(orgId, item.getId(), defaultWarehouseId)
                            .map(StockBalance::getQuantityOnHand)
                            .orElse(BigDecimal.ZERO);
                }

                String taxGroupName = item.getDefaultTaxGroupId() != null
                        ? taxGroupNames.get(item.getDefaultTaxGroupId()) : null;

                posItems.add(new CachedPosItem(
                        item.getId(), item.getName(), item.getSku(), item.getBarcode(),
                        item.getSalePrice(), item.getMrp(), item.getPurchasePrice(),
                        item.getDefaultTaxGroupId(), taxGroupName,
                        item.getHsnCode(), item.getUnitOfMeasure(),
                        currentStock, item.isWeightBasedBilling(), item.isTrackBatches()));
            }
            page++;
        } while (itemPage.hasNext());

        cacheService.put(CacheKeys.posItems(orgId), posItems, Duration.ofMinutes(30));
        log.info("[CacheWarmer] Warmed POS items cache with {} items for org={}", posItems.size(), orgId);
        return posItems.size();
    }
}
