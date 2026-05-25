package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.dto.DrugMasterResponse;
import com.katasticho.erp.inventory.dto.SaltMasterResponse;
import com.katasticho.erp.inventory.service.DrugMasterService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/drug-master")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
public class DrugMasterController {

    private final DrugMasterService drugMasterService;

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
