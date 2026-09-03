package com.katasticho.erp.franchise.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.franchise.dto.*;
import com.katasticho.erp.franchise.service.FranchiseCatalogSyncService;
import com.katasticho.erp.franchise.service.FranchiseRoyaltyService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/franchise")
@RequiredArgsConstructor
public class FranchiseController {

    private final FranchiseCatalogSyncService catalogSyncService;
    private final FranchiseRoyaltyService royaltyService;

    // --- Franchise Nodes ---

    @GetMapping("/nodes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<List<FranchiseNodeResponse>> listNodes() {
        return ApiResponse.ok(catalogSyncService.listNodes(TenantContext.getCurrentOrgId()));
    }

    @PostMapping("/nodes")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<FranchiseNodeResponse> createNode(@RequestBody FranchiseNodeRequest req) {
        return ApiResponse.ok(catalogSyncService.createNode(TenantContext.getCurrentOrgId(), req));
    }

    @PutMapping("/nodes/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<FranchiseNodeResponse> updateNode(@PathVariable UUID id, @RequestBody FranchiseNodeRequest req) {
        return ApiResponse.ok(catalogSyncService.updateNode(TenantContext.getCurrentOrgId(), id, req));
    }

    @DeleteMapping("/nodes/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<String> deleteNode(@PathVariable UUID id) {
        catalogSyncService.deleteNode(TenantContext.getCurrentOrgId(), id);
        return ApiResponse.ok("Deleted");
    }

    // --- Catalog Policy ---

    @GetMapping("/policy")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<FranchiseCatalogPolicyResponse> getPolicy() {
        return ApiResponse.ok(catalogSyncService.getPolicy(TenantContext.getCurrentOrgId()));
    }

    @PutMapping("/policy")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<FranchiseCatalogPolicyResponse> savePolicy(@RequestBody FranchiseCatalogPolicyRequest req) {
        return ApiResponse.ok(catalogSyncService.savePolicy(TenantContext.getCurrentOrgId(), req));
    }

    // --- Catalog Push ---

    @PostMapping("/catalog-sync")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<CatalogSyncResultResponse> pushCatalog(@RequestBody CatalogSyncPushRequest req) {
        return ApiResponse.ok(catalogSyncService.pushCatalogToBranches(TenantContext.getCurrentOrgId(), req));
    }

    // --- Branch Price Overrides ---

    @GetMapping("/branches/{branchId}/price-overrides")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ApiResponse<List<BranchPriceOverrideResponse>> getBranchOverrides(@PathVariable UUID branchId) {
        return ApiResponse.ok(catalogSyncService.getBranchOverrides(TenantContext.getCurrentOrgId(), branchId));
    }

    @PostMapping("/price-overrides")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<BranchPriceOverrideResponse> savePriceOverride(@RequestBody BranchPriceOverrideRequest req) {
        return ApiResponse.ok(catalogSyncService.savePriceOverride(TenantContext.getCurrentOrgId(), req));
    }

    @DeleteMapping("/price-overrides/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ApiResponse<String> deletePriceOverride(@PathVariable UUID id) {
        catalogSyncService.deletePriceOverride(TenantContext.getCurrentOrgId(), id);
        return ApiResponse.ok("Deleted");
    }

    // --- Royalty Settlements ---

    @GetMapping("/settlements")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ApiResponse<List<FranchiseRoyaltySettlementResponse>> listSettlements(@RequestParam(required = false) UUID nodeId) {
        return ApiResponse.ok(royaltyService.listSettlements(TenantContext.getCurrentOrgId(), nodeId));
    }

    @PostMapping("/settlements/calculate")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<FranchiseRoyaltySettlementResponse> calculateSettlement(@RequestBody FranchiseRoyaltySettlementRequest req) {
        return ApiResponse.ok(royaltyService.calculateSettlement(TenantContext.getCurrentOrgId(), req));
    }

    @PostMapping("/settlements/{id}/invoice")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<FranchiseRoyaltySettlementResponse> generateRoyaltyInvoice(@PathVariable UUID id) {
        return ApiResponse.ok(royaltyService.generateRoyaltyInvoice(TenantContext.getCurrentOrgId(), id));
    }
}