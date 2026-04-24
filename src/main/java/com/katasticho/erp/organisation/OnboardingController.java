package com.katasticho.erp.organisation;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/onboarding")
@RequiredArgsConstructor
public class OnboardingController {

    private final IndustryTemplateRepository templateRepository;
    private final IndustrySubCategoryRepository subCategoryRepository;

    /**
     * Returns the distinct business types for onboarding Screen 1.
     * Example: ["RETAILER", "DISTRIBUTOR", "MANUFACTURER", "SERVICE_PROVIDER"]
     */
    @GetMapping("/business-types")
    public ResponseEntity<List<String>> getBusinessTypes() {
        return ResponseEntity.ok(templateRepository.findDistinctBusinessTypes());
    }

    /**
     * Returns active industry templates for a given business type.
     * Used for onboarding Screen 2 (pick your industry).
     */
    @GetMapping("/industries")
    public ResponseEntity<List<Map<String, Object>>> getIndustries(
            @RequestParam String businessType) {
        List<IndustryTemplate> templates =
                templateRepository.findByBusinessTypeAndActiveTrueOrderBySortOrder(businessType);
        List<Map<String, Object>> result = templates.stream()
                .map(t -> Map.<String, Object>of(
                        "industryCode", t.getIndustryCode(),
                        "industryLabel", t.getIndustryLabel(),
                        "industryIcon", t.getIndustryIcon() != null ? t.getIndustryIcon() : "",
                        "sortOrder", t.getSortOrder()))
                .collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    /**
     * Returns active sub-categories for a given industry code.
     * Used for onboarding Screen 3 (pick specialisation).
     * Returns an empty list if the industry has no sub-categories.
     */
    @GetMapping("/sub-categories")
    public ResponseEntity<List<Map<String, Object>>> getSubCategories(
            @RequestParam String industryCode) {
        return templateRepository.findByIndustryCode(industryCode)
                .map(template -> {
                    List<IndustrySubCategory> subs =
                            subCategoryRepository.findByIndustryTemplateIdAndActiveTrueOrderBySortOrder(template.getId());
                    List<Map<String, Object>> result = subs.stream()
                            .map(s -> Map.<String, Object>of(
                                    "subCategoryCode", s.getSubCategoryCode(),
                                    "subCategoryLabel", s.getSubCategoryLabel(),
                                    "sortOrder", s.getSortOrder()))
                            .collect(Collectors.toList());
                    return ResponseEntity.ok(result);
                })
                .orElse(ResponseEntity.ok(List.of()));
    }
}
