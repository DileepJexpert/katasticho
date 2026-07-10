package com.katasticho.erp.common.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.service.ModuleVisibilityService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * Per-org authoritative module-visibility overrides — the backing API for the
 * "Modules" settings screen. Reads are open to any authenticated user (the
 * sidebar applies the overrides for everyone in the org); writes are OWNER/ADMIN.
 *
 * <p>Everything here resolves the org from {@link TenantContext}, so an org can
 * only ever read/write its OWN overrides — no cross-tenant impact.
 */
@RestController
@RequestMapping("/api/v1/settings/module-visibility")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class ModuleVisibilityController {

    private final ModuleVisibilityService service;

    /** Current overrides + the full list of module codes (for rendering the screen). */
    @GetMapping
    public ResponseEntity<Map<String, Object>> get() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(Map.of(
                "overrides", service.getOverrides(orgId),
                "modules", ModuleCode.ALL));
    }

    /** Show/hide one module for this org (explicit — wins over the industry default). */
    @PutMapping("/{module}")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, Boolean>> setOne(
            @PathVariable String module,
            @RequestBody Map<String, Boolean> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        boolean visible = Boolean.TRUE.equals(body.get("visible"));
        return ResponseEntity.ok(service.setOverride(orgId, module, visible));
    }

    /** Remove one module's override → it reverts to the industry/flag default. */
    @DeleteMapping("/{module}")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, Boolean>> clearOne(@PathVariable String module) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(service.clearOverride(orgId, module));
    }

    /** Replace the whole override map in one call (for a Save-all screen). */
    @PutMapping
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, Boolean>> setAll(@RequestBody Map<String, Object> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Object raw = body.get("overrides");
        Map<String, Boolean> overrides = new java.util.LinkedHashMap<>();
        if (raw instanceof Map<?, ?> m) {
            m.forEach((k, v) -> {
                if (k != null && v instanceof Boolean b) {
                    overrides.put(k.toString(), b);
                }
            });
        }
        return ResponseEntity.ok(service.setAll(orgId, overrides));
    }

    /** Clear all overrides → the whole org reverts to its industry/flag defaults. */
    @PostMapping("/reset")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> reset() {
        UUID orgId = TenantContext.getCurrentOrgId();
        service.reset(orgId);
        return ResponseEntity.ok(Map.of("status", "reset"));
    }
}
