package com.katasticho.erp.pos.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.pos.dto.PosSearchResult;
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

    private boolean canSeeCostPrice(Authentication auth) {
        if (auth == null) return false;
        return auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_OWNER") || a.getAuthority().equals("ROLE_ADMIN"));
    }
}
