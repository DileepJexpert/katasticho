package com.katasticho.erp.courier.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.courier.dto.CodRemittanceDtos.*;
import com.katasticho.erp.courier.service.CodReconciliationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/courier/cod-remittances")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.COURIER)
public class CodRemittanceController {

    private final CodReconciliationService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<CodRemittanceResponse>> create(
            @Valid @RequestBody CreateCodRemittanceRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(service.create(request)));
    }

    /** Walk lines, post payments for MATCHED, flag mismatches, surface orphans. */
    @PostMapping("/{id}/reconcile")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ReconcileResult>> reconcile(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.reconcile(id), "COD remittance reconciled"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<CodRemittanceResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<CodRemittanceResponse>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(service.list()));
    }
}
