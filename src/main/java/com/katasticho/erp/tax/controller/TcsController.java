package com.katasticho.erp.tax.controller;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.tax.service.TcsService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * TCS 206C(1H) compliance: org-level enable/rate settings, the collection
 * register (for the monthly deposit challan) and quarterly Form 27EQ data.
 * Collection itself happens automatically on sales invoices once the buyer's
 * FY consideration crosses ₹50 lakh.
 */
@RestController
@RequestMapping("/api/v1/tcs")
@RequiredArgsConstructor
@RequiresCountry("IN")
public class TcsController {

    private final TcsService tcsService;
    private final OrgSettingsService orgSettingsService;

    /** Invoices with TCS collected in the range — what to deposit via ITNS-281. */
    @GetMapping("/register")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> register(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ResponseEntity.ok(ApiResponse.ok(tcsService.register(from, to)));
    }

    /** Quarterly Form 27EQ data: collectee-wise summary. fy = FY start year. */
    @GetMapping("/27eq")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> form27eq(
            @RequestParam int fy,
            @RequestParam int quarter) {
        return ResponseEntity.ok(ApiResponse.ok(tcsService.form27eq(fy, quarter)));
    }

    @GetMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("enabled", tcsService.isEnabled(orgId));
        out.put("rate", orgSettingsService.get(orgId, TcsService.SETTING_RATE, TcsService.DEFAULT_RATE));
        return ResponseEntity.ok(ApiResponse.ok(out));
    }

    /** Enable/disable TCS and set the rate (applies only if the seller's turnover > ₹10 crore). */
    @PutMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> updateSettings(
            @RequestBody Map<String, Object> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (body.containsKey("enabled")) {
            orgSettingsService.set(orgId, TcsService.SETTING_ENABLED,
                    String.valueOf(Boolean.parseBoolean(String.valueOf(body.get("enabled")))));
        }
        if (body.containsKey("rate")) {
            orgSettingsService.set(orgId, TcsService.SETTING_RATE,
                    new java.math.BigDecimal(String.valueOf(body.get("rate"))).toPlainString());
        }
        return getSettings();
    }
}
