package com.katasticho.erp.common.cache;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class CacheInvalidationService {

    private final CacheService cacheService;

    public void onItemChanged(UUID orgId, UUID itemId) {
        log.info("[CacheInvalidation] Item changed org={} item={}", orgId, itemId);
        cacheService.evict(CacheKeys.itemPrice(orgId, itemId));
        cacheService.evictOrgCache(CacheKeys.STOCK_BALANCE, orgId);
        cacheService.evict(CacheKeys.posItems(orgId));
        cacheService.evict(CacheKeys.lowStock(orgId));
    }

    public void onStockMovement(UUID orgId, UUID itemId, UUID warehouseId) {
        log.info("[CacheInvalidation] Stock movement org={} item={} wh={}", orgId, itemId, warehouseId);
        cacheService.evict(CacheKeys.stockBalance(orgId, itemId, warehouseId));
        cacheService.evict(CacheKeys.posItems(orgId));
        cacheService.evict(CacheKeys.lowStock(orgId));
        cacheService.evict(CacheKeys.dailySummary(orgId));
    }

    public void onInvoiceChanged(UUID orgId, UUID contactId) {
        log.info("[CacheInvalidation] Invoice changed org={} contact={}", orgId, contactId);
        if (contactId != null) {
            cacheService.evict(CacheKeys.customerOutstanding(orgId, contactId));
        }
        cacheService.evict(CacheKeys.arSummary(orgId));
        cacheService.evict(CacheKeys.dailySummary(orgId));
    }

    public void onPaymentReceived(UUID orgId, UUID contactId) {
        log.info("[CacheInvalidation] Payment received org={} contact={}", orgId, contactId);
        if (contactId != null) {
            cacheService.evict(CacheKeys.customerOutstanding(orgId, contactId));
        }
        cacheService.evict(CacheKeys.arSummary(orgId));
        cacheService.evict(CacheKeys.dailySummary(orgId));
    }

    public void onPosSale(UUID orgId) {
        log.info("[CacheInvalidation] POS sale completed org={}", orgId);
        cacheService.evict(CacheKeys.dailySummary(orgId));
    }

    public void onContactChanged(UUID orgId, UUID contactId) {
        log.info("[CacheInvalidation] Contact changed org={} contact={}", orgId, contactId);
        cacheService.evict(CacheKeys.customerOutstanding(orgId, contactId));
    }

    public void evictAllForOrg(UUID orgId) {
        log.info("[CacheInvalidation] Evicting ALL cache for org={}", orgId);
        cacheService.evictOrgCache(CacheKeys.ITEM_PRICE, orgId);
        cacheService.evictOrgCache(CacheKeys.STOCK_BALANCE, orgId);
        cacheService.evict(CacheKeys.posItems(orgId));
        cacheService.evictOrgCache(CacheKeys.CUSTOMER_OUTSTANDING, orgId);
        cacheService.evict(CacheKeys.dailySummary(orgId));
        cacheService.evict(CacheKeys.arSummary(orgId));
        cacheService.evict(CacheKeys.lowStock(orgId));
        cacheService.evict(CacheKeys.expiringSoon(orgId));
        cacheService.evict(CacheKeys.warmerStatus(orgId));
    }
}
