package com.katasticho.erp.pos.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.pos.dto.PosSearchResult;
import com.katasticho.erp.pos.service.PosCatalogService;
import com.katasticho.erp.pos.service.PosCatalogSyncService;
import com.katasticho.erp.pos.service.PosSearchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/items")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.POS)
public class PosSearchController {

    private final PosSearchService posSearchService;
    private final PosCatalogService posCatalogService;
    private final PosCatalogSyncService posCatalogSyncService;

    /**
     * Fast POS item search — optimized for counter billing speed.
     * Ranked: exact barcode > exact SKU > name prefix > name contains.
     * Cached in Redis for 5 minutes per (org, query) pair.
     */
    @GetMapping("/pos-search")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<PosSearchResult>>> posSearch(
            @RequestParam String q,
            @RequestParam(name = "branch_id", required = false) UUID branchId,
            @RequestParam(defaultValue = "20") int limit,
            Authentication auth) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<PosSearchResult> results = posSearchService.search(orgId, q, branchId, limit);
        if (!canSeeCostPrice(auth)) {
            results = results.stream().map(r -> new PosSearchResult(
                    r.id(), r.name(), r.sku(), r.barcode(), r.rate(), r.mrp(),
                    null,
                    r.taxGroupId(), r.taxGroupName(), r.hsnCode(), r.unit(),
                    r.currentStock(), r.weightBasedBilling(), r.batchId(),
                    r.batchExpiryDate(), r.trackBatches(), r.batchNumber(),
                    r.discountThresholds(), r.prescriptionRequired(),
                    r.drugSchedule(), r.composition(), r.manufacturer(), r.rackLocationCode()
            )).toList();
        }
        return ResponseEntity.ok(ApiResponse.ok(results));
    }

    /**
     * Marg-style catalog quick-add: create an org item from a drug-master
     * entry and return it as a billable POS search result. OPERATOR allowed
     * by design - the counter seller is exactly who hits an uncatalogued
     * medicine mid-bill. Cost price is not involved (purchase price is null).
     */
    @PostMapping("/from-drug/{drugId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PosSearchResult>> createFromDrug(
            @PathVariable UUID drugId,
            @RequestParam(name = "branch_id", required = false) UUID branchId,
            @RequestParam(name = "opening_stock", required = false) java.math.BigDecimal openingStock) {
        return ResponseEntity.ok(ApiResponse.ok(
                posCatalogService.createItemFromDrug(drugId, branchId, openingStock),
                "Item added from catalog"));
    }

    /**
     * POS catalog delta sync — items changed since {@code since} (or full
     * snapshot if absent). The client persists {@code nextSince} and pages
     * through with {@code hasMore}. This is what powers the local-first POS
     * search: the client searches its own SQLite, this keeps it fresh.
     */
    @GetMapping("/pos-sync")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<java.util.Map<String, Object>>> posSync(
            @RequestParam(required = false) String since,
            @RequestParam(name = "since_id", required = false) UUID sinceId,
            @RequestParam(name = "branch_id", required = false) UUID branchId,
            @RequestParam(name = "page_size", defaultValue = "500") int pageSize) {
        java.time.Instant from = (since == null || since.isBlank())
                ? null : java.time.Instant.parse(since);
        return ResponseEntity.ok(ApiResponse.ok(
                posCatalogSyncService.sync(from, sinceId, branchId, pageSize)));
    }

    private boolean canSeeCostPrice(Authentication auth) {
        if (auth == null) return false;
        return auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_OWNER") || a.getAuthority().equals("ROLE_ADMIN"));
    }
}
