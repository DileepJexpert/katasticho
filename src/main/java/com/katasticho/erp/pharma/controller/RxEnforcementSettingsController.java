package com.katasticho.erp.pharma.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Prescription enforcement mode for pharmacy POS.
 *
 * <p>In India most pharmacies sell common Rx drugs (Amoxicillin, Omeprazole,
 * Metformin, …) without a paper prescription — the regulator-perfect "block
 * sale" path is not how the market operates. So the default for IN orgs is
 * <b>WARN</b> (cashier sees the dialog with a "Sell without Rx" button); other
 * jurisdictions (UAE, Oman, …) default to <b>STRICT</b> where the dialog
 * blocks. Org admins can override.
 *
 * <p>Stored as the {@code pharma.rx_enforcement_mode} org_settings key, so it
 * follows the same "settings as policy layer" rule the rest of the system uses.
 */
@RestController
@RequestMapping("/api/v1/settings/pharma/rx-enforcement")
@RequiredArgsConstructor
public class RxEnforcementSettingsController {

    public static final String SETTING_KEY = "pharma.rx_enforcement_mode";
    public static final String MODE_OFF    = "OFF";
    public static final String MODE_WARN   = "WARN";
    public static final String MODE_STRICT = "STRICT";
    private static final Set<String> VALID_MODES = Set.of(MODE_OFF, MODE_WARN, MODE_STRICT);

    private final OrgSettingsService orgSettingsService;
    private final OrganisationRepository organisationRepository;

    @GetMapping
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<Map<String, Object>>> get() {
        UUID orgId = TenantContext.getCurrentOrgId();
        String stored = orgSettingsService.get(orgId, SETTING_KEY, null);
        String mode = stored != null ? stored : defaultForOrg(orgId);
        return ResponseEntity.ok(ApiResponse.ok(Map.of(
                "mode", mode,
                "isDefault", stored == null,
                "country", organisationRepository.findById(orgId)
                        .map(Organisation::getCountryCode).orElse("IN"))));
    }

    @PutMapping
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> set(@RequestBody Map<String, String> body) {
        String mode = body.get("mode");
        if (mode == null || !VALID_MODES.contains(mode)) {
            throw new BusinessException(
                    "Mode must be one of OFF, WARN, STRICT",
                    "PHARMA_RX_MODE_INVALID", HttpStatus.BAD_REQUEST);
        }
        UUID orgId = TenantContext.getCurrentOrgId();
        orgSettingsService.set(orgId, SETTING_KEY, mode);
        return ResponseEntity.ok(ApiResponse.ok(Map.of("mode", mode)));
    }

    /** UAE / Oman / Saudi require a real Rx by statute; India is treated as
     *  permissive by default because that's how 99% of chemists actually
     *  operate. Org admins can override at any time. */
    private String defaultForOrg(UUID orgId) {
        return organisationRepository.findById(orgId)
                .map(Organisation::getCountryCode)
                .map(c -> "IN".equalsIgnoreCase(c) ? MODE_WARN : MODE_STRICT)
                .orElse(MODE_WARN);
    }
}
