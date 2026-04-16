package com.katasticho.erp.pos.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.pos.dto.PosSearchResult;
import com.katasticho.erp.pos.service.PosSearchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/items")
@RequiredArgsConstructor
public class PosSearchController {

    private final PosSearchService posSearchService;

    /**
     * Fast POS item search — optimized for counter billing speed.
     * Ranked: exact barcode > exact SKU > name prefix > name contains.
     * Cached in Redis for 5 minutes per (org, query) pair.
     */
    @GetMapping("/pos-search")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<PosSearchResult>>> posSearch(
            @RequestParam String q,
            @RequestParam(name = "branch_id", required = false) UUID branchId,
            @RequestParam(defaultValue = "20") int limit) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<PosSearchResult> results = posSearchService.search(orgId, q, branchId, limit);
        return ResponseEntity.ok(ApiResponse.ok(results));
    }
}
