package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.inventory.dto.ShortbookItemResponse;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.inventory.repository.WarehouseRepository;
import com.katasticho.erp.sales.repository.SalesOrderLineRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class ShortbookService {

    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final WarehouseRepository warehouseRepository;
    private final SalesOrderLineRepository soLineRepository;

    @Transactional(readOnly = true)
    public List<ShortbookItemResponse> getShortbook() {
        UUID orgId = TenantContext.getCurrentOrgId();

        // Default warehouse id (for stock lookup)
        UUID warehouseId = warehouseRepository
                .findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                .map(w -> w.getId())
                .orElse(null);

        // 1. Backorder items: aggregate quantityBackordered per itemId from BACKORDER SOs
        Map<UUID, BigDecimal> backorderedByItem = new LinkedHashMap<>();
        soLineRepository.findAllBackorderedItems(orgId).forEach(row -> {
            UUID itemId = (UUID) row[0];
            BigDecimal qty = (BigDecimal) row[1];
            backorderedByItem.merge(itemId, qty, BigDecimal::add);
        });

        // 2. Low stock items: items where onHand <= reorderLevel (and reorderLevel > 0)
        Map<UUID, BigDecimal> lowStockItems = new LinkedHashMap<>();
        if (warehouseId != null) {
            stockBalanceRepository.findByOrgIdAndWarehouseId(orgId, warehouseId).forEach(bal -> {
                Item item = itemRepository.findById(bal.getItemId()).orElse(null);
                if (item == null || !item.isTrackInventory() || item.isDeleted()) return;
                if (item.getReorderLevel().compareTo(BigDecimal.ZERO) > 0
                        && bal.getQuantityOnHand().compareTo(item.getReorderLevel()) <= 0) {
                    lowStockItems.put(item.getId(), bal.getQuantityOnHand());
                }
            });
        }

        // 3. Merge both sets
        Set<UUID> allItemIds = new LinkedHashSet<>();
        allItemIds.addAll(backorderedByItem.keySet());
        allItemIds.addAll(lowStockItems.keySet());

        List<ShortbookItemResponse> result = new ArrayList<>();
        for (UUID itemId : allItemIds) {
            Item item = itemRepository.findById(itemId).orElse(null);
            if (item == null || item.isDeleted()) continue;

            BigDecimal onHand = BigDecimal.ZERO;
            if (warehouseId != null) {
                onHand = stockBalanceRepository
                        .findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId)
                        .map(StockBalance::getQuantityOnHand)
                        .orElse(BigDecimal.ZERO);
            }

            BigDecimal backordered = backorderedByItem.getOrDefault(itemId, BigDecimal.ZERO);
            boolean isLowStock = lowStockItems.containsKey(itemId);
            boolean isBackorder = backordered.compareTo(BigDecimal.ZERO) > 0;

            String reason = isBackorder && isLowStock ? "BOTH"
                    : isBackorder ? "BACKORDER"
                    : "LOW_STOCK";

            // Suggest: max of (backordered qty, reorder qty deficit)
            BigDecimal reorderQty = item.getReorderQuantity();
            BigDecimal deficit = item.getReorderLevel().subtract(onHand).max(BigDecimal.ZERO);
            BigDecimal suggestQty = reorderQty.max(backordered).max(deficit);

            result.add(new ShortbookItemResponse(
                    item.getId(),
                    item.getName(),
                    item.getSku(),
                    item.getHsnCode(),
                    onHand,
                    item.getReorderLevel(),
                    item.getReorderQuantity(),
                    backordered,
                    suggestQty,
                    reason
            ));
        }

        return result;
    }
}
