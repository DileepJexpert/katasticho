package com.katasticho.erp.organisation;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.entity.OrgBootstrapStatus;
import com.katasticho.erp.common.entity.OrgFeatureFlag;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.repository.OrgBootstrapStatusRepository;
import com.katasticho.erp.common.service.FeatureFlagService;
import com.katasticho.erp.inventory.service.UomService;
import com.katasticho.erp.organisation.dto.UpdateIndustryRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/organisations")
@RequiredArgsConstructor
public class OrganisationController {

    private final OrganisationRepository organisationRepository;
    private final FeatureFlagService featureFlagService;
    private final UomService uomService;
    private final OrgBootstrapStatusRepository bootstrapStatusRepository;

    @PutMapping("/{id}/industry")
    public ResponseEntity<Map<String, Object>> updateIndustry(
            @PathVariable UUID id,
            @RequestBody UpdateIndustryRequest req) {

        UUID callerOrgId = TenantContext.getCurrentOrgId();
        if (!callerOrgId.equals(id)) {
            throw new BusinessException("Forbidden", "ORG_FORBIDDEN", HttpStatus.FORBIDDEN);
        }

        Organisation org = organisationRepository.findById(id)
                .orElseThrow(() -> BusinessException.notFound("Organisation", id));

        if (req.businessType() != null) org.setBusinessType(req.businessType());
        if (req.industryCode() != null) org.setIndustryCode(req.industryCode());
        if (req.subCategories() != null) org.setSubCategories(req.subCategories());
        if (req.gstin() != null) org.setGstin(req.gstin());
        if (req.state() != null) org.setState(req.state());
        if (req.stateCode() != null) org.setStateCode(req.stateCode());
        if (req.phone() != null) org.setPhone(req.phone());
        organisationRepository.save(org);

        List<String> subCats = org.getSubCategories();
        if (subCats != null && !subCats.isEmpty()) {
            featureFlagService.seedForSubCategories(id, subCats);
        } else {
            featureFlagService.seedForIndustry(id, org.getIndustryCode());
        }

        List<OrgFeatureFlag> flags = featureFlagService.listAll(id);
        List<String> enabledFeatures = flags.stream()
                .filter(OrgFeatureFlag::isEnabled)
                .map(OrgFeatureFlag::getFeature)
                .toList();

        return ResponseEntity.ok(Map.of(
                "industryCode", org.getIndustryCode(),
                "businessType", org.getBusinessType(),
                "subCategories", org.getSubCategories(),
                "enabledFeatures", enabledFeatures
        ));
    }

    @PostMapping("/{id}/onboarding-complete")
    public ResponseEntity<Map<String, Boolean>> completeOnboarding(@PathVariable UUID id) {
        UUID callerOrgId = TenantContext.getCurrentOrgId();
        if (!callerOrgId.equals(id)) {
            throw new BusinessException("Forbidden", "ORG_FORBIDDEN", HttpStatus.FORBIDDEN);
        }

        OrgBootstrapStatus status = bootstrapStatusRepository.findById(id)
                .orElseGet(() -> OrgBootstrapStatus.builder().orgId(id).build());
        status.setOnboardingCompleted(true);
        bootstrapStatusRepository.save(status);

        return ResponseEntity.ok(Map.of("onboardingCompleted", true));
    }

    @GetMapping("/{id}/onboarding-status")
    public ResponseEntity<Map<String, Object>> getOnboardingStatus(@PathVariable UUID id) {
        UUID callerOrgId = TenantContext.getCurrentOrgId();
        if (!callerOrgId.equals(id)) {
            throw new BusinessException("Forbidden", "ORG_FORBIDDEN", HttpStatus.FORBIDDEN);
        }

        boolean completed = bootstrapStatusRepository.findById(id)
                .map(OrgBootstrapStatus::isOnboardingCompleted)
                .orElse(false);

        return ResponseEntity.ok(Map.of("onboardingCompleted", completed));
    }
}
