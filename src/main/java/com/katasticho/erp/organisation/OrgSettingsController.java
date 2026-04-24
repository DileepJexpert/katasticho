package com.katasticho.erp.organisation;

import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/settings")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class OrgSettingsController {

    private final OrgSettingsService settingsService;

    @GetMapping
    public ResponseEntity<Map<String, String>> getAll() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return ResponseEntity.ok(settingsService.getAll(orgId));
    }

    @PutMapping
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> updateAll(@RequestBody Map<String, String> settings) {
        UUID orgId = TenantContext.getCurrentOrgId();
        settingsService.setBulk(orgId, settings);
        return ResponseEntity.ok(settingsService.getAll(orgId));
    }

    @GetMapping("/{key}")
    public ResponseEntity<Map<String, String>> getOne(@PathVariable String key) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String value = settingsService.get(orgId, key, null);
        if (value == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(Map.of(key, value));
    }

    @PutMapping("/{key}")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public ResponseEntity<Map<String, String>> setOne(
            @PathVariable String key,
            @RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String value = body.get("value");
        if (value == null) value = body.get(key);
        settingsService.set(orgId, key, value);
        return ResponseEntity.ok(Map.of(key, settingsService.get(orgId, key, "")));
    }
}
