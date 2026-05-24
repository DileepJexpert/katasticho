package com.katasticho.erp.pharma.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.pharma.dto.DrugLicenseRequest;
import com.katasticho.erp.pharma.dto.DrugLicenseResponse;
import com.katasticho.erp.pharma.service.DrugLicenseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/drug-licenses")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
public class DrugLicenseController {

    private final DrugLicenseService drugLicenseService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DrugLicenseResponse>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(drugLicenseService.list()));
    }

    @GetMapping("/expiring")
    public ResponseEntity<ApiResponse<List<DrugLicenseResponse>>> getExpiring(
            @RequestParam(defaultValue = "30") int days) {
        return ResponseEntity.ok(ApiResponse.ok(drugLicenseService.getExpiring(days)));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<DrugLicenseResponse>> create(
            @Valid @RequestBody DrugLicenseRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(drugLicenseService.create(request)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<DrugLicenseResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody DrugLicenseRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(drugLicenseService.update(id, request)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        drugLicenseService.delete(id);
        return ResponseEntity.ok(ApiResponse.ok(null));
    }
}
