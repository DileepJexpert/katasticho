package com.katasticho.erp.transport.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.transport.dto.FleetDtos.*;
import com.katasticho.erp.transport.service.ProofOfDeliveryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/** Proof of delivery — recipient/GPS + signature/photo evidence. */
@RestController
@RequestMapping("/api/v1/transport/proof-of-delivery")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.TRANSPORT)
public class ProofOfDeliveryController {

    private final ProofOfDeliveryService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PodResponse>> create(
            @Valid @RequestBody CreatePodRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(service.create(request)));
    }

    /** Attach a signature/photo file to a POD. */
    @PostMapping(value = "/{id}/attachments", consumes = "multipart/form-data")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<PodResponse>> attach(
            @PathVariable UUID id, @RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(ApiResponse.ok(service.attach(id, file), "Evidence attached"));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PodResponse>> get(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(service.get(id)));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<PodResponse>>> list(
            @RequestParam(required = false) UUID deliveryChallanId) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(deliveryChallanId)));
    }
}
