package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.dto.CreateUomRequest;
import com.katasticho.erp.inventory.dto.UomResponse;
import com.katasticho.erp.inventory.entity.UomCategory;
import com.katasticho.erp.inventory.service.UomService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * UoM master CRUD. Seed data is written by the V13 migration — the
 * write endpoints are only used when an org wants to add custom UoMs
 * (e.g. "Dozen", "Carton") or deactivate seeded ones.
 */
@RestController
@RequestMapping("/api/v1/uoms")
@RequiredArgsConstructor
public class UomController {

    private final UomService uomService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<UomResponse>>> list(
            @RequestParam(required = false) UomCategory category) {
        List<UomResponse> uoms = category != null
                ? uomService.listByCategory(category)
                : uomService.listForCurrentOrg();
        return ResponseEntity.ok(ApiResponse.ok(uoms));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<UomResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(uomService.get(id)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<UomResponse>> create(
            @Valid @RequestBody CreateUomRequest request) {
        UomResponse created = uomService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(created));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<UomResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody CreateUomRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(uomService.update(id, request), "UoM updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        uomService.softDelete(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "UoM deleted"));
    }
}
