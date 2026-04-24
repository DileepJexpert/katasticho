package com.katasticho.erp.common.cache;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/cache")
@RequiredArgsConstructor
@Slf4j
public class CacheAdminController {

    private final DailyCacheWarmer dailyCacheWarmer;
    private final CacheInvalidationService cacheInvalidationService;
    private final CacheService cacheService;

    @PostMapping("/warm")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> warmCurrentOrg() {
        UUID orgId = TenantContext.getCurrentOrgId();
        log.info("[CacheAdmin] Manual cache warm triggered for org={}", orgId);
        Map<String, Object> result = dailyCacheWarmer.warmSingleOrg(orgId);
        return ResponseEntity.ok(ApiResponse.ok(result, "Cache warmed"));
    }

    @PostMapping("/warm/{orgId}")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> warmOrg(@PathVariable UUID orgId) {
        log.info("[CacheAdmin] Manual cache warm triggered for specific org={}", orgId);
        Map<String, Object> result = dailyCacheWarmer.warmSingleOrg(orgId);
        return ResponseEntity.ok(ApiResponse.ok(result, "Cache warmed for org " + orgId));
    }

    @DeleteMapping("/evict")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<String>> evictCurrentOrg() {
        UUID orgId = TenantContext.getCurrentOrgId();
        log.info("[CacheAdmin] Manual cache evict for org={}", orgId);
        cacheInvalidationService.evictAllForOrg(orgId);
        return ResponseEntity.ok(ApiResponse.ok("Cache evicted for org " + orgId));
    }

    @DeleteMapping("/evict/{key}")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<String>> evictKey(@PathVariable String key) {
        log.info("[CacheAdmin] Manual evict key={}", key);
        cacheService.evict(key);
        return ResponseEntity.ok(ApiResponse.ok("Evicted key: " + key));
    }

    @GetMapping("/stats")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStats() {
        Map<String, Object> stats = cacheService.getStats();
        return ResponseEntity.ok(ApiResponse.ok(stats));
    }

    @GetMapping("/status")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<Object>> getWarmerStatus() {
        UUID orgId = TenantContext.getCurrentOrgId();
        String key = CacheKeys.warmerStatus(orgId);
        var status = cacheService.get(key, Map.class);
        return ResponseEntity.ok(ApiResponse.ok(status.orElse(Map.of("status", "never_warmed"))));
    }
}
