package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.dto.DrugMasterImportResult;
import com.katasticho.erp.inventory.dto.DrugMasterResponse;
import com.katasticho.erp.inventory.dto.SaltMasterResponse;
import com.katasticho.erp.inventory.service.DrugMasterImportService;
import com.katasticho.erp.inventory.service.DrugMasterService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/drug-master")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
public class DrugMasterController {

    private final DrugMasterService drugMasterService;
    private final DrugMasterImportService drugMasterImportService;

    /**
     * Bulk CSV import into the shared platform catalogue (Marg / 1mg / Apollo /
     * DavaIndia-style lists). Add-only — existing brands are never mutated —
     * mirroring the HSN-master precedent for OWNER/ADMIN writes to platform
     * reference tables. Use dry_run=true to preview counts without saving.
     */
    @PostMapping("/import")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<DrugMasterImportResult>> importCsv(
            @RequestParam("file") MultipartFile file,
            @RequestParam(name = "dry_run", defaultValue = "false") boolean dryRun) {
        return ResponseEntity.ok(ApiResponse.ok(drugMasterImportService.importCsv(file, dryRun)));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<List<DrugMasterResponse>>> searchDrugs(
            @RequestParam(name = "q", defaultValue = "") String q,
            @RequestParam(name = "limit", defaultValue = "20") int limit) {
        List<DrugMasterResponse> results = drugMasterService.searchDrugs(q, Math.min(limit, 100));
        return ResponseEntity.ok(ApiResponse.ok(results));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<DrugMasterResponse>> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(drugMasterService.getById(id)));
    }

    @GetMapping("/salts/search")
    public ResponseEntity<ApiResponse<List<SaltMasterResponse>>> searchSalts(
            @RequestParam(name = "q", defaultValue = "") String q,
            @RequestParam(name = "limit", defaultValue = "20") int limit) {
        List<SaltMasterResponse> results = drugMasterService.searchSalts(q, Math.min(limit, 100));
        return ResponseEntity.ok(ApiResponse.ok(results));
    }
}
