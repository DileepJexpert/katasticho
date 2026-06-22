package com.katasticho.erp.ap.match;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ap/three-way-match")
@RequiredArgsConstructor
public class ThreeWayMatchController {

    private final ThreeWayMatchService threeWayMatchService;
    private final OrgSettingsService orgSettingsService;

    @PostMapping("/{billId}/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<String>> run(@PathVariable UUID billId) {
        String status = threeWayMatchService.match(billId);
        return ResponseEntity.ok(ApiResponse.ok(status, "Match completed: " + status));
    }

    @GetMapping("/{billId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<ThreeWayMatchService.MatchSnapshot>> get(@PathVariable UUID billId) {
        return ResponseEntity.ok(ApiResponse.ok(threeWayMatchService.get(billId)));
    }

    @GetMapping("/exceptions")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Page<BillMatchResultLine>>> exceptions(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        return ResponseEntity.ok(ApiResponse.ok(threeWayMatchService.listExceptions(pageable)));
    }

    @PostMapping("/{billId}/override")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> override(
            @PathVariable UUID billId,
            @RequestBody Map<String, String> body) {
        threeWayMatchService.override(billId, body.get("reason"));
        return ResponseEntity.ok(ApiResponse.ok(null, "Match overridden"));
    }

    @GetMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, String>>> getSettings() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, String> s = new HashMap<>();
        s.put("required", orgSettingsService.get(orgId, "ap.three_way_match.required", "true"));
        s.put("qty_tolerance_pct",
                orgSettingsService.get(orgId, "ap.three_way_match.qty_tolerance_pct", "0"));
        s.put("price_tolerance_abs",
                orgSettingsService.get(orgId, "ap.three_way_match.price_tolerance_abs", "1"));
        s.put("price_tolerance_pct",
                orgSettingsService.get(orgId, "ap.three_way_match.price_tolerance_pct", "0.005"));
        s.put("bypass_threshold",
                orgSettingsService.get(orgId, "ap.three_way_match.bypass_threshold", "0"));
        return ResponseEntity.ok(ApiResponse.ok(s));
    }

    @PutMapping("/settings")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> putSettings(@RequestBody Map<String, String> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        for (Map.Entry<String, String> e : body.entrySet()) {
            String k = e.getKey();
            // Only accept the keys we own — don't let arbitrary settings be written through here.
            if (!k.startsWith("ap.three_way_match.") &&
                    !k.equals("required") && !k.equals("qty_tolerance_pct")
                    && !k.equals("price_tolerance_abs") && !k.equals("price_tolerance_pct")
                    && !k.equals("bypass_threshold")) continue;
            String fullKey = k.startsWith("ap.three_way_match.") ? k : "ap.three_way_match." + k;
            orgSettingsService.set(orgId, fullKey, e.getValue());
        }
        return ResponseEntity.ok(ApiResponse.ok(null, "Settings updated"));
    }
}
