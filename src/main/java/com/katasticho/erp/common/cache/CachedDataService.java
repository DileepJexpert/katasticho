package com.katasticho.erp.common.cache;

import com.fasterxml.jackson.core.type.TypeReference;
import com.katasticho.erp.common.cache.dto.*;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBalance;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBalanceRepository;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.entity.Invoice;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class CachedDataService {

    private final CacheService cacheService;
    private final ItemRepository itemRepository;
    private final StockBalanceRepository stockBalanceRepository;
    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;

    public Optional<CachedItemPrice> getItemPrice(UUID orgId, UUID itemId) {
        String key = CacheKeys.itemPrice(orgId, itemId);
        Optional<CachedItemPrice> cached = cacheService.get(key, CachedItemPrice.class);

        if (cached.isPresent()) {
            log.debug("[CachedData] Item price from CACHE org={} item={}", orgId, itemId);
            return cached;
        }

        log.info("[CachedData] Item price from DB (cache miss/heal) org={} item={}", orgId, itemId);
        Optional<Item> itemOpt = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId);
        if (itemOpt.isEmpty()) return Optional.empty();

        Item item = itemOpt.get();
        CachedItemPrice price = new CachedItemPrice(
                item.getId(), item.getName(), item.getSku(), item.getBarcode(),
                item.getSalePrice(), item.getPurchasePrice(), item.getMrp(),
                item.getGstRate(), item.getDefaultTaxGroupId(),
                item.getHsnCode(), item.getUnitOfMeasure(), item.isActive());
        cacheService.put(key, price);
        return Optional.of(price);
    }

    public Optional<CachedStockBalance> getStockBalance(UUID orgId, UUID itemId, UUID warehouseId) {
        String key = CacheKeys.stockBalance(orgId, itemId, warehouseId);
        Optional<CachedStockBalance> cached = cacheService.get(key, CachedStockBalance.class);

        if (cached.isPresent()) {
            log.debug("[CachedData] Stock balance from CACHE org={} item={} wh={}", orgId, itemId, warehouseId);
            return cached;
        }

        log.info("[CachedData] Stock balance from DB (cache miss/heal) org={} item={} wh={}", orgId, itemId, warehouseId);
        Optional<StockBalance> balOpt = stockBalanceRepository.findByOrgIdAndItemIdAndWarehouseId(orgId, itemId, warehouseId);
        Optional<Item> itemOpt = itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId);

        BigDecimal reorderLevel = itemOpt.map(Item::getReorderLevel).orElse(BigDecimal.ZERO);

        if (balOpt.isEmpty()) {
            CachedStockBalance zero = new CachedStockBalance(
                    itemId, warehouseId, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, reorderLevel);
            cacheService.put(key, zero, cacheService.getShortTtl());
            return Optional.of(zero);
        }

        StockBalance bal = balOpt.get();
        CachedStockBalance result = new CachedStockBalance(
                itemId, warehouseId, bal.getQuantityOnHand(), bal.getReservedQty(),
                bal.getAverageCost(), reorderLevel);
        cacheService.put(key, result);
        return Optional.of(result);
    }

    public Optional<CachedCustomerOutstanding> getCustomerOutstanding(UUID orgId, UUID contactId) {
        String key = CacheKeys.customerOutstanding(orgId, contactId);
        Optional<CachedCustomerOutstanding> cached = cacheService.get(key, CachedCustomerOutstanding.class);

        if (cached.isPresent()) {
            log.debug("[CachedData] Customer outstanding from CACHE org={} contact={}", orgId, contactId);
            return cached;
        }

        log.info("[CachedData] Customer outstanding from DB (cache miss/heal) org={} contact={}", orgId, contactId);
        Optional<Contact> contactOpt = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId);
        if (contactOpt.isEmpty()) return Optional.empty();

        Contact contact = contactOpt.get();
        List<Invoice> outstanding = invoiceRepository.findOutstandingByContact(orgId, contactId);
        BigDecimal ar = outstanding.stream()
                .map(Invoice::getBalanceDue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        CachedCustomerOutstanding result = new CachedCustomerOutstanding(
                contactId, contact.getDisplayName(), ar,
                contact.getCreditLimit(), outstanding.size());
        cacheService.put(key, result);
        return Optional.of(result);
    }

    public Optional<CachedDailySummary> getDailySummary(UUID orgId) {
        String key = CacheKeys.dailySummary(orgId);
        Optional<CachedDailySummary> cached = cacheService.get(key, CachedDailySummary.class);
        if (cached.isPresent()) {
            log.debug("[CachedData] Daily summary from CACHE org={}", orgId);
            return cached;
        }
        log.info("[CachedData] Daily summary MISS for org={} - not self-healing (expensive query)", orgId);
        return Optional.empty();
    }

    public List<CachedPosItem> getPosItems(UUID orgId) {
        String key = CacheKeys.posItems(orgId);
        Optional<List<CachedPosItem>> cached = cacheService.get(key, new TypeReference<>() {});
        if (cached.isPresent()) {
            log.debug("[CachedData] POS items from CACHE org={} count={}", orgId, cached.get().size());
            return cached.get();
        }
        log.info("[CachedData] POS items MISS for org={} - returning empty, warmer will repopulate", orgId);
        return List.of();
    }
}
