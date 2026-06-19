package com.katasticho.erp.transport.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.transport.dto.FleetDtos.*;
import com.katasticho.erp.transport.service.VehicleLogService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Own-fleet running-cost log + per-vehicle TCO summary. */
@RestController
@RequestMapping("/api/v1/transport/vehicle-logs")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.TRANSPORT)
public class VehicleLogController {

    private final VehicleLogService service;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<VehicleLogResponse>> create(
            @Valid @RequestBody VehicleLogRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(service.create(request)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null, "Entry removed"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<VehicleLogResponse>>> list(
            @RequestParam(required = false) String vehicleNumber) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(vehicleNumber)));
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<VehicleTcoSummary>> summary(
            @RequestParam String vehicleNumber) {
        return ResponseEntity.ok(ApiResponse.ok(service.summary(vehicleNumber)));
    }
}
