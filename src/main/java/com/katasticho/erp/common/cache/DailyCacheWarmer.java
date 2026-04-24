package com.katasticho.erp.common.cache;

import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class DailyCacheWarmer {

    private final OrganisationRepository organisationRepository;
    private final ItemCacheWarmer itemCacheWarmer;
    private final CustomerCacheWarmer customerCacheWarmer;
    private final SummaryCacheWarmer summaryCacheWarmer;
    private final CacheService cacheService;

    @Scheduled(cron = "${cache.warmer.cron:0 0 5 * * *}")
    public void warmAllOrgs() {
        log.info("[DailyCacheWarmer] === Starting daily cache warm for all orgs ===");
        Instant start = Instant.now();

        List<Organisation> orgs = organisationRepository.findByIsDeletedFalseAndActiveTrue();
        log.info("[DailyCacheWarmer] Found {} active organisations to warm", orgs.size());

        int successCount = 0;
        int failCount = 0;

        for (Organisation org : orgs) {
            try {
                warmSingleOrg(org.getId());
                successCount++;
            } catch (Exception e) {
                failCount++;
                log.error("[DailyCacheWarmer] Failed to warm org={} ({}): {}",
                        org.getId(), org.getName(), e.getMessage(), e);
            }
        }

        Duration elapsed = Duration.between(start, Instant.now());
        log.info("[DailyCacheWarmer] === Completed: {}/{} orgs warmed in {}ms ===",
                successCount, orgs.size(), elapsed.toMillis());
    }

    @Async
    public void warmSingleOrgAsync(UUID orgId) {
        try {
            warmSingleOrg(orgId);
        } catch (Exception e) {
            log.error("[DailyCacheWarmer] Async warm failed for org={}: {}", orgId, e.getMessage(), e);
        }
    }

    public Map<String, Object> warmSingleOrg(UUID orgId) {
        log.info("[DailyCacheWarmer] Warming cache for org={}", orgId);
        Instant start = Instant.now();
        Map<String, Object> result = new LinkedHashMap<>();

        try {
            int itemCount = itemCacheWarmer.warmItemPrices(orgId);
            result.put("itemPrices", itemCount);
        } catch (Exception e) {
            log.error("[DailyCacheWarmer] Item price warm failed for org={}: {}", orgId, e.getMessage());
            result.put("itemPricesError", e.getMessage());
        }

        try {
            int stockCount = itemCacheWarmer.warmStockBalances(orgId);
            result.put("stockBalances", stockCount);
        } catch (Exception e) {
            log.error("[DailyCacheWarmer] Stock balance warm failed for org={}: {}", orgId, e.getMessage());
            result.put("stockBalancesError", e.getMessage());
        }

        try {
            int posCount = itemCacheWarmer.warmPosItems(orgId);
            result.put("posItems", posCount);
        } catch (Exception e) {
            log.error("[DailyCacheWarmer] POS items warm failed for org={}: {}", orgId, e.getMessage());
            result.put("posItemsError", e.getMessage());
        }

        try {
            int custCount = customerCacheWarmer.warmCustomerOutstanding(orgId);
            result.put("customerOutstanding", custCount);
        } catch (Exception e) {
            log.error("[DailyCacheWarmer] Customer outstanding warm failed for org={}: {}", orgId, e.getMessage());
            result.put("customerOutstandingError", e.getMessage());
        }

        try {
            summaryCacheWarmer.warmDailySummary(orgId);
            result.put("dailySummary", "OK");
        } catch (Exception e) {
            log.error("[DailyCacheWarmer] Daily summary warm failed for org={}: {}", orgId, e.getMessage());
            result.put("dailySummaryError", e.getMessage());
        }

        Duration elapsed = Duration.between(start, Instant.now());
        result.put("durationMs", elapsed.toMillis());
        log.info("[DailyCacheWarmer] Org {} warm complete in {}ms: {}", orgId, elapsed.toMillis(), result);

        Map<String, Object> status = new LinkedHashMap<>();
        status.put("lastWarmAt", Instant.now().toString());
        status.put("durationMs", elapsed.toMillis());
        status.put("result", result);
        cacheService.put(CacheKeys.warmerStatus(orgId), status, Duration.ofHours(24));

        return result;
    }
}
