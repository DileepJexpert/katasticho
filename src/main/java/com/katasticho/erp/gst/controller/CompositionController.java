package com.katasticho.erp.gst.controller;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.gst.service.CompositionService;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * GST composition scheme: enable/rate settings and the quarterly CMP-08
 * statement. When enabled, the compliance calendar swaps GSTR-1/3B/2B for
 * CMP-08 + annual GSTR-4.
 */
@RestController
@RequestMapping("/api/v1/gst/composition")
@RequiredArgsConstructor
@RequiresCountry("IN")
public class CompositionController {

    private final CompositionService compositionService;
    private final OrgSettingsService orgSettingsService;

    /** CMP-08 data for a quarter. fy = FY start year (2026 = FY 2026-27). */
    @GetMapping("/cmp08")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> cmp08(
            @RequestParam int fy,
            @RequestParam int quarter) {
        return ResponseEntity.ok(ApiResponse.ok(compositionService.cmp08(fy, quarter)));
    }

    @GetMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("enabled", compositionService.isEnabled(orgId));
        out.put("rate", compositionService.rate(orgId).toPlainString());
        return ResponseEntity.ok(ApiResponse.ok(out));
    }

    /** Switch the org onto/off the composition scheme and set the flat rate. */
    @PutMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSettings(
            @RequestBody Map<String, Object> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (body.containsKey("enabled")) {
            orgSettingsService.set(orgId, CompositionService.SETTING_ENABLED,
                    String.valueOf(Boolean.parseBoolean(String.valueOf(body.get("enabled")))));
        }
        if (body.containsKey("rate")) {
            orgSettingsService.set(orgId, CompositionService.SETTING_RATE,
                    new java.math.BigDecimal(String.valueOf(body.get("rate"))).toPlainString());
        }
        return getSettings();
    }
}
