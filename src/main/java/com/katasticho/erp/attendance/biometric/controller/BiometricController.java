package com.katasticho.erp.attendance.biometric.controller;

import com.katasticho.erp.attendance.biometric.entity.BiometricDevice;
import com.katasticho.erp.attendance.biometric.service.BiometricService;
import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/biometric")
@RequiredArgsConstructor
public class BiometricController {

    private final BiometricService biometricService;

    @GetMapping("/devices")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<BiometricDevice>>> listDevices() {
        return ResponseEntity.ok(ApiResponse.ok(biometricService.listDevices()));
    }

    @PostMapping("/devices")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<BiometricDevice>> registerDevice(
            @RequestBody BiometricService.DeviceRegisterRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(biometricService.registerDevice(req), "Biometric device registered"));
    }

    @PutMapping("/devices/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<BiometricDevice>> updateDevice(
            @PathVariable UUID id,
            @RequestBody BiometricService.DeviceRegisterRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(biometricService.updateDevice(id, req), "Biometric device updated"));
    }

    @DeleteMapping("/devices/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteDevice(@PathVariable UUID id) {
        biometricService.deleteDevice(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Device deleted"));
    }

    @PostMapping("/devices/{id}/test-connection")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testConnection(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(biometricService.testConnection(id)));
    }

    @GetMapping("/logs")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<List<BiometricService.PunchLogResponse>>> getLogs() {
        return ResponseEntity.ok(ApiResponse.ok(biometricService.getRecentLogs()));
    }

    @PostMapping("/logs/simulate")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<BiometricService.PunchLogResponse>> simulatePunch(
            @RequestBody BiometricService.SimulatePunchRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(biometricService.simulatePunch(req), "Simulated punch recorded"));
    }
}
