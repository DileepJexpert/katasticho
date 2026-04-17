package com.katasticho.erp.tax.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.tax.dto.TaxAccountMappingResponse;
import com.katasticho.erp.tax.dto.UpdateTaxAccountMappingsRequest;
import com.katasticho.erp.tax.service.TaxAccountMappingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Settings → Taxes & Compliance → Tax Account Mapping.
 *
 * GET   — list every TaxRate with its current GL input/output accounts.
 * PUT   — bulk-rebind rates to different CoA accounts.
 * POST  /reset — drop customisations and re-seed defaults.
 */
@RestController
@RequestMapping("/api/v1/settings/tax-accounts")
@RequiredArgsConstructor
public class TaxAccountMappingController {

    private final TaxAccountMappingService service;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<TaxAccountMappingResponse>>> list() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(service.listForOrg(orgId)));
    }

    @PutMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<TaxAccountMappingResponse>>> update(
            @Valid @RequestBody UpdateTaxAccountMappingsRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(
                service.updateMappings(orgId, request),
                "Tax account mappings updated"));
    }

    @PostMapping("/reset")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<ApiResponse<List<TaxAccountMappingResponse>>> reset() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(ApiResponse.ok(
                service.resetForOrg(orgId),
                "Tax account mappings reset to defaults"));
    }
}
