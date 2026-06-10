package com.katasticho.erp.auth.controller;

import com.katasticho.erp.auth.dto.ApiKeyResponse;
import com.katasticho.erp.auth.dto.CreateApiKeyRequest;
import com.katasticho.erp.auth.dto.CreatedApiKeyResponse;
import com.katasticho.erp.auth.service.ApiKeyService;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Manage org API keys (programmatic credentials for the MCP server,
 * integrations, scripts). Owner/Admin only. The secret is shown once at
 * creation and never again.
 */
@RestController
@RequestMapping("/api/v1/api-keys")
@RequiredArgsConstructor
public class ApiKeyController {

    private final ApiKeyService apiKeyService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<CreatedApiKeyResponse>> create(
            @Valid @RequestBody CreateApiKeyRequest request) {
        CreatedApiKeyResponse created = apiKeyService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(created));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<List<ApiKeyResponse>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(apiKeyService.list()));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> revoke(@PathVariable UUID id) {
        apiKeyService.revoke(id);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null, "API key revoked"));
    }
}
