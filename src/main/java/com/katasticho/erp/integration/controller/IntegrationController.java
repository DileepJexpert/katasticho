package com.katasticho.erp.integration.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.integration.entity.IntegrationConfig;
import com.katasticho.erp.integration.entity.IntegrationSyncLog;
import com.katasticho.erp.integration.service.IntegrationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/integrations")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN')")
public class IntegrationController {

    private final IntegrationService service;

    // ── Config CRUD ───────────────────────────────────────────────────────────

    @PostMapping
    public ApiResponse<IntegrationConfig> create(@RequestBody Map<String, Object> body) {
        String type    = (String) body.get("integrationType");
        String name    = (String) body.get("name");
        String baseUrl = (String) body.get("baseUrl");
        String apiKey  = (String) body.get("apiKey");
        @SuppressWarnings("unchecked")
        Map<String, Object> settings = (Map<String, Object>) body.get("settings");
        return ApiResponse.created(service.createConfig(type, name, baseUrl, apiKey, settings));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<List<IntegrationConfig>> list() {
        return ApiResponse.ok(service.listConfigs());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<IntegrationConfig> get(@PathVariable UUID id) {
        return ApiResponse.ok(service.getConfig(id));
    }

    @PutMapping("/{id}")
    public ApiResponse<IntegrationConfig> update(@PathVariable UUID id,
                                                  @RequestBody Map<String, Object> body) {
        String name    = (String) body.get("name");
        String baseUrl = (String) body.get("baseUrl");
        String apiKey  = (String) body.get("apiKey");
        Boolean active = body.containsKey("isActive") ? (Boolean) body.get("isActive") : null;
        @SuppressWarnings("unchecked")
        Map<String, Object> settings = (Map<String, Object>) body.get("settings");
        return ApiResponse.ok(service.updateConfig(id, name, baseUrl, apiKey, settings, active));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(@PathVariable UUID id) {
        service.deleteConfig(id);
        return ApiResponse.ok(null);
    }

    // ── Connection Test ───────────────────────────────────────────────────────

    @PostMapping("/{id}/test-connection")
    public ApiResponse<Map<String, Object>> testConnection(@PathVariable UUID id) {
        return ApiResponse.ok(service.testConnection(id));
    }

    // ── Sync ──────────────────────────────────────────────────────────────────

    @PostMapping("/{id}/sync")
    public ApiResponse<IntegrationSyncLog> sync(
            @PathVariable UUID id,
            @RequestParam(defaultValue = "GENERAL") String syncType,
            @RequestParam(defaultValue = "EXPORT") String direction) {
        return ApiResponse.ok(service.syncData(id, syncType, direction));
    }

    @GetMapping("/{id}/history")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ApiResponse<List<IntegrationSyncLog>> history(@PathVariable UUID id) {
        return ApiResponse.ok(service.getSyncHistory(id));
    }
}
