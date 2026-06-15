package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.entity.Warehouse;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

/**
 * POS catalog delta sync. The POS client keeps a LOCAL catalog cache and
 * searches it instantly (no network in the hot path); this endpoint hands it
 * the delta of items changed since the client's last sync, so the cache stays
 * current.
 *
 * <p>Stock numbers here are advisory — the authoritative check still happens
 * at receipt-post time, which is what keeps multi-terminal selling correct
 * (the server rejects oversold lines).
 */
@Service
@RequiredArgsConstructor
public class PosCatalogSyncService {

    /** Hard cap so a single sync call never returns more than this many rows. */
    private static final int MAX_PAGE_SIZE = 1000;

    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final WarehouseRepository warehouseRepository;

    /**
     * Delta of items changed since {@code since} (or full snapshot when null).
     * Returned in {@code updatedAt} ascending order, with a {@code nextSince}
     * cursor; the client persists it and passes it back next time.
     *
     * <p>{@code isDeleted} rows are included so the client can prune its cache.
     */
    private static final UUID NIL_UUID = new UUID(0, 0);

    @Transactional(readOnly = true)
    public Map<String, Object> sync(Instant since, UUID sinceId, UUID warehouseId, int pageSize) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Instant from = since == null ? Instant.EPOCH : since;
        UUID fromId = sinceId == null ? NIL_UUID : sinceId;
        int size = Math.min(Math.max(pageSize, 1), MAX_PAGE_SIZE);

        UUID whId = warehouseId != null ? warehouseId : warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(Warehouse::getId).orElse(null);

        List<Item> items = itemRepository
                .findChangedSince(orgId, from, fromId, PageRequest.of(0, size))
                .getContent();

        Map<UUID, BigDecimal> stockByItem = loadStock(orgId, whId, items);

        List<Map<String, Object>> rows = new ArrayList<>(items.size());
        Instant cursor = from;
        UUID cursorId = fromId;
        for (Item it : items) {
            rows.add(row(it, stockByItem.get(it.getId())));
            if (it.getUpdatedAt() != null) {
                cursor = it.getUpdatedAt();
                cursorId = it.getId();
            }
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("items", rows);
        out.put("count", rows.size());
        out.put("nextSince", cursor);
        out.put("nextSinceId", cursorId);
        out.put("hasMore", rows.size() >= size);
        out.put("totalCount", itemRepository.countByOrgId(orgId));
        return out;
    }

    private Map<UUID, BigDecimal> loadStock(UUID orgId, UUID whId, List<Item> items) {
        if (whId == null || items.isEmpty()) return Map.of();
        Map<UUID, BigDecimal> m = new HashMap<>();
        for (Item it : items) {
            stockBalanceRepository
                    .findByOrgIdAndItemIdAndWarehouseId(orgId, it.getId(), whId)
                    .map(StockBalance::getQuantityOnHand)
                    .ifPresent(q -> m.put(it.getId(), q));
        }
        return m;
    }

    /**
     * Slim catalog row — only the fields the POS client renders on search /
     * uses in the cart. Field names match the existing {@code posSearch}
     * response so the client code is unchanged.
     */
    private Map<String, Object> row(Item it, BigDecimal stock) {
        BigDecimal rate = it.getSalePrice();
        if ((rate == null || rate.signum() <= 0) && it.getMrp() != null) rate = it.getMrp();

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("itemId", it.getId());
        m.put("id", it.getId());
        m.put("name", it.getName());
        m.put("sku", it.getSku());
        m.put("barcode", it.getBarcode());
        m.put("hsnCode", it.getHsnCode());
        m.put("unit", it.getUnitOfMeasure());
        m.put("rate", rate);
        m.put("mrp", it.getMrp());
        m.put("gstRate", it.getGstRate());
        m.put("currentStock", stock != null ? stock : BigDecimal.ZERO);
        m.put("trackBatches", it.isTrackBatches());
        m.put("weightBasedBilling", it.isWeightBasedBilling());
        m.put("composition", it.getComposition());
        m.put("manufacturer", it.getManufacturer());
        m.put("prescriptionRequired", it.isPrescriptionRequired());
        m.put("drugSchedule", it.getDrugSchedule());
        m.put("updatedAt", it.getUpdatedAt());
        m.put("isDeleted", it.isDeleted());
        return m;
    }
}
