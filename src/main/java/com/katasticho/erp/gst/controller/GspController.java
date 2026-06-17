package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import com.katasticho.erp.gst.service.GspClient;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * GSP (GST Suvidha Provider) connection settings — the credentials that let an
 * org generate IRNs and e-way bills directly instead of the manual
 * download-JSON → portal-upload flow. The token is write-only (never echoed).
 */
@RestController
@RequestMapping("/api/v1/gst/gsp-settings")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.GST)
public class GspController {

    private final GspClient gspClient;
    private final OrgSettingsService orgSettingsService;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get() {
        return ResponseEntity.ok(ApiResponse.ok(gspClient.settings(TenantContext.getCurrentOrgId())));
    }

    @PutMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> update(@RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        putIfPresent(orgId, body, "enabled", GspClient.ENABLED);
        putIfPresent(orgId, body, "provider", GspClient.PROVIDER);
        putIfPresent(orgId, body, "baseUrl", GspClient.BASE_URL);
        putIfPresent(orgId, body, "einvoicePath", GspClient.EINVOICE_PATH);
        putIfPresent(orgId, body, "ewaybillPath", GspClient.EWAYBILL_PATH);
        putIfPresent(orgId, body, "gstr2bPath", GspClient.GSTR2B_PATH);
        putIfPresent(orgId, body, "gstr2aPath", GspClient.GSTR2A_PATH);
        putIfPresent(orgId, body, "gstin", GspClient.GSTIN);
        // Only overwrite the token when a non-blank value is supplied.
        if (body.get("token") != null && !body.get("token").isBlank()) {
            orgSettingsService.set(orgId, GspClient.TOKEN, body.get("token").trim());
        }
        return ResponseEntity.ok(ApiResponse.ok(gspClient.settings(orgId), "GSP settings updated"));
    }

    /** Probe whether the configured GSP host is reachable. Never errors on a bad host. */
    @PostMapping("/test")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> test() {
        return ResponseEntity.ok(ApiResponse.ok(
                gspClient.testConnection(TenantContext.getCurrentOrgId())));
    }

    private void putIfPresent(UUID orgId, Map<String, String> body, String field, String key) {
        if (body.containsKey(field)) {
            orgSettingsService.set(orgId, key, body.get(field) == null ? "" : body.get(field).trim());
        }
    }
}
