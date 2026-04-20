package com.katasticho.erp.common.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.OrgFeatureFlag;
import com.katasticho.erp.common.service.FeatureFlagService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;


@RestController
@RequestMapping("/api/v1/settings/features")
@RequiredArgsConstructor
public class FeatureFlagController {

    private final FeatureFlagService featureFlagService;
    private final OrganisationRepository organisationRepository;

    @GetMapping
    public ResponseEntity<Map<String, Object>> listFeatures() {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<OrgFeatureFlag> flags = featureFlagService.listAll(orgId);

        List<Map<String, Object>> items = flags.stream()
                .map(f -> Map.<String, Object>of(
                        "feature", f.getFeature(),
                        "enabled", f.isEnabled()
                ))
                .toList();

        return ResponseEntity.ok(Map.of("data", items));
    }

    @PutMapping("/{feature}")
    public ResponseEntity<Map<String, Object>> toggleFeature(
            @PathVariable String feature,
            @RequestBody Map<String, Boolean> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        boolean enabled = Boolean.TRUE.equals(body.get("enabled"));

        if (enabled) {
            featureFlagService.enable(orgId, feature);
        } else {
            featureFlagService.disable(orgId, feature);
        }

        return ResponseEntity.ok(Map.of("feature", feature, "enabled", enabled));
    }

    @PostMapping("/reset")
    public ResponseEntity<Map<String, String>> resetToDefaults() {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId).orElseThrow();
        List<String> subCats = org.getSubCategories();
        if (subCats != null && !subCats.isEmpty()) {
            featureFlagService.seedForSubCategories(orgId, subCats);
        } else {
            featureFlagService.seedForIndustry(orgId, org.getIndustryCode());
        }
        return ResponseEntity.ok(Map.of("status", "reset"));
    }
}
