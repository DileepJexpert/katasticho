package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.dto.*;
import com.katasticho.erp.inventory.service.PharmacyMasterService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/pharmacy-masters")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class PharmacyMasterController {

    private final PharmacyMasterService service;

    @GetMapping("/manufacturers/search")
    public ResponseEntity<ApiResponse<List<ManufacturerMasterResponse>>> manufacturers(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(ApiResponse.ok(service.searchManufacturers(q, limit)));
    }

    @GetMapping("/hsn/search")
    public ResponseEntity<ApiResponse<List<HsnGstMasterResponse>>> hsnSearch(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(ApiResponse.ok(service.searchHsn(q, limit)));
    }

    @GetMapping("/hsn/{code}")
    public ResponseEntity<ApiResponse<HsnGstMasterResponse>> hsnByCode(@PathVariable String code) {
        return ResponseEntity.ok(ApiResponse.ok(service.getHsn(code)));
    }

    @GetMapping("/rack-locations")
    public ResponseEntity<ApiResponse<List<RackLocationResponse>>> rackLocations(
            @RequestParam UUID warehouseId) {
        return ResponseEntity.ok(ApiResponse.ok(service.rackLocations(warehouseId)));
    }

    @PostMapping("/rack-locations")
    public ResponseEntity<ApiResponse<RackLocationResponse>> createRackLocation(
            @Valid @RequestBody RackLocationRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(service.createRackLocation(request), "Rack location saved"));
    }

    @GetMapping("/substitutions")
    public ResponseEntity<ApiResponse<List<GenericSubstitutionResponse>>> substitutions(
            @RequestParam UUID drugMasterId) {
        return ResponseEntity.ok(ApiResponse.ok(service.substitutions(drugMasterId)));
    }

    @GetMapping("/interactions/check")
    public ResponseEntity<ApiResponse<List<DrugInteractionResponse>>> interactionCheck(
            @RequestParam List<UUID> saltIds) {
        return ResponseEntity.ok(ApiResponse.ok(service.checkInteractions(saltIds)));
    }
}
