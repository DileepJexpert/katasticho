package com.katasticho.erp.ai.controller;

import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.dto.AiModelSettingsRequest;
import com.katasticho.erp.ai.dto.AiModelSettingsResponse;
import com.katasticho.erp.ai.service.OrgAiSettingsService;
import com.katasticho.erp.ai.service.VisionModelRouter;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/settings/ai")
@RequiredArgsConstructor
public class OrgAiSettingsController {

    private final OrgAiSettingsService service;
    private final AiConfig aiConfig;
    private final VisionModelRouter modelRouter;

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<AiModelSettingsResponse>> get() {
        return ResponseEntity.ok(ApiResponse.ok(service.getSettings()));
    }

    @PutMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<AiModelSettingsResponse>> update(
            @Valid @RequestBody AiModelSettingsRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateSettings(req)));
    }

    @PostMapping("/test")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testConnection(
            @RequestBody Map<String, String> body) {
        String baseUrl = body.get("baseUrl");
        if (baseUrl == null || baseUrl.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("baseUrl is required"));
        }
        boolean ok = service.testOllamaConnection(baseUrl);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("success", ok,
                "message", ok ? "Connected successfully" : "Cannot reach Ollama server")));
    }

    /** Lists models installed on the given local server (Ollama /api/tags). */
    @GetMapping("/models")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<java.util.List<String>>> installedModels(
            @RequestParam String baseUrl) {
        return ResponseEntity.ok(ApiResponse.ok(service.listInstalledModels(baseUrl)));
    }

    /** Current AI provider status — which backend is active, connectivity, model info. */
    @GetMapping("/status")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> status() {
        boolean useLocal = aiConfig.isUseLocal();
        String provider = useLocal ? "OLLAMA" : aiConfig.getDefaultProvider();
        String model = useLocal ? aiConfig.getOllamaModel() : aiConfig.getModel();
        String baseUrl = useLocal ? aiConfig.getOllamaBaseUrl() : "https://api.anthropic.com";

        boolean reachable = false;
        if (useLocal) {
            reachable = service.testOllamaConnection(aiConfig.getOllamaBaseUrl());
        } else {
            String key = aiConfig.getAnthropicApiKey();
            reachable = key != null && !key.isBlank();
        }

        java.util.LinkedHashMap<String, Object> status = new java.util.LinkedHashMap<>();
        status.put("useLocal", useLocal);
        status.put("provider", provider);
        status.put("model", model);
        status.put("baseUrl", baseUrl);
        status.put("reachable", reachable);
        status.put("ollamaBaseUrl", aiConfig.getOllamaBaseUrl());
        status.put("ollamaModel", aiConfig.getOllamaModel());
        return ResponseEntity.ok(ApiResponse.ok(status));
    }
}
