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
import java.util.Map;
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

    @PostMapping("/hsn")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','PLATFORM_ADMIN')")
    public ResponseEntity<ApiResponse<HsnGstMasterResponse>> upsertHsn(
            @RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(ApiResponse.ok(service.upsertHsn(
                (String) body.get("hsnCode"),
                (String) body.get("description"),
                (String) body.get("category"),
                body.get("gstRate") != null
                        ? new java.math.BigDecimal(body.get("gstRate").toString()) : null),
                "HSN saved"));
    }

    @GetMapping("/rack-locations")
    public ResponseEntity<ApiResponse<List<RackLocationResponse>>> rackLocations(
            @RequestParam(required = false) UUID warehouseId) {
        return ResponseEntity.ok(ApiResponse.ok(service.rackLocations(warehouseId)));
    }

    @PostMapping("/rack-locations")
    public ResponseEntity<ApiResponse<RackLocationResponse>> createRackLocation(
            @Valid @RequestBody RackLocationRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(service.createRackLocation(request), "Rack location saved"));
    }

    @PostMapping("/rack-locations/seed-demo")
    public ResponseEntity<ApiResponse<List<RackLocationResponse>>> seedDemoRackLocations() {
        return ResponseEntity.ok(ApiResponse.ok(service.seedDemoRackLocations(), "Demo rack layout loaded"));
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

    @GetMapping("/interactions/check-by-composition")
    public ResponseEntity<ApiResponse<List<DrugInteractionResponse>>> interactionCheckByComposition(
            @RequestParam List<String> compositions) {
        return ResponseEntity.ok(ApiResponse.ok(service.checkInteractionsByCompositions(compositions)));
    }
}
