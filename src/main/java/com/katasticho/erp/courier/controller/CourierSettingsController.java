package com.katasticho.erp.courier.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.courier.service.CourierClient;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Per-partner courier credentials (BlueDart, Delhivery, India Post, DTDC,
 * Shiprocket). Mirrors {@code GspController} exactly — tokens are write-only.
 */
@RestController
@RequestMapping("/api/v1/courier/settings")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.COURIER)
public class CourierSettingsController {

    private final CourierClient courierClient;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get() {
        return ResponseEntity.ok(ApiResponse.ok(
                courierClient.settings(TenantContext.getCurrentOrgId())));
    }

    @PutMapping("/{partner}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> update(
            @PathVariable String partner, @RequestBody Map<String, String> body) {
        courierClient.updateSettings(TenantContext.getCurrentOrgId(), partner, body);
        return ResponseEntity.ok(ApiResponse.ok(
                courierClient.settings(TenantContext.getCurrentOrgId()),
                partner + " settings updated"));
    }

    @PostMapping("/{partner}/test")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> test(@PathVariable String partner) {
        return ResponseEntity.ok(ApiResponse.ok(
                courierClient.testConnection(TenantContext.getCurrentOrgId(), partner)));
    }
}
