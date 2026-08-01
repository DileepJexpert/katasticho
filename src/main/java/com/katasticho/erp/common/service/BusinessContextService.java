package com.katasticho.erp.common.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Lightweight cached business-context resolver for the current tenant org.
 *
 * <p>Used when shared platform reference data must stay global in the DB but be
 * ranked or presented differently per business vertical. This deliberately does
 * not decide hard access control for vertical catalogs; strict access stays on
 * {@code @RequiresModule} / {@code ModuleAccessService}. Its job is "how should
 * a shared reference search behave for this org?".
 */
@Service
@RequiredArgsConstructor
public class BusinessContextService {

    private final OrganisationRepository organisationRepository;

    private final ConcurrentHashMap<UUID, OrgBusinessProfile> cache = new ConcurrentHashMap<>();

    public OrgBusinessProfile currentProfile() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required",
                    "ORG_CONTEXT_REQUIRED", HttpStatus.FORBIDDEN);
        }
        return profileOf(orgId);
    }

    public OrgBusinessProfile profileOf(UUID orgId) {
        return cache.computeIfAbsent(orgId, id ->
                organisationRepository.findById(id)
                        .map(this::toProfile)
                        .orElse(OrgBusinessProfile.defaultProfile()));
    }

    /**
     * Category preference order for shared HSN/GST search results.
     *
     * <p>HSN is universal statutory reference data, so we do not hide rows by
     * vertical. Instead we bias the ranking toward categories that are more
     * relevant for the onboarded business profile.
     */
    public List<String> preferredHsnCategories() {
        OrgBusinessProfile profile = currentProfile();
        if (profile.isPharmaLike()) {
            return List.of("PHARMA", "MEDICAL", "SURGICAL", "PERSONAL_CARE");
        }
        if (profile.isGroceryLike()) {
            return List.of("GROCERY", "FOOD_BEVERAGE", "PERSONAL_CARE", "HOUSEHOLD");
        }
        if (profile.isFoodLike()) {
            return List.of("FOOD_BEVERAGE", "GROCERY", "PERSONAL_CARE");
        }
        if (profile.isPersonalCareLike()) {
            return List.of("PERSONAL_CARE", "GROCERY");
        }
        return List.of();
    }

    public void evict(UUID orgId) {
        cache.remove(orgId);
    }

    private OrgBusinessProfile toProfile(Organisation org) {
        return new OrgBusinessProfile(
                normalize(org.getBusinessType()),
                normalize(org.getIndustryCode()),
                normalize(org.getCountryCode()));
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
    }

    public record OrgBusinessProfile(String businessType, String industryCode, String countryCode) {

        static OrgBusinessProfile defaultProfile() {
            return new OrgBusinessProfile("RETAILER", "OTHER_RETAIL", "IN");
        }

        boolean isPharmaLike() {
            return containsAny(industryCode, "PHARMA", "PHARMACY", "MEDICAL");
        }

        boolean isGroceryLike() {
            return containsAny(industryCode, "GROCERY", "KIRANA", "SUPERMARKET", "GENERAL_TRADE")
                    || containsAny(businessType, "GROCERY");
        }

        boolean isFoodLike() {
            return containsAny(industryCode, "FOOD", "BEVERAGE", "BAKERY", "RESTAURANT", "DAIRY");
        }

        boolean isPersonalCareLike() {
            return containsAny(industryCode, "COSMETIC", "PERSONAL_CARE", "BEAUTY", "SALON");
        }

        private static boolean containsAny(String haystack, String... needles) {
            for (String needle : needles) {
                if (haystack.contains(needle)) {
                    return true;
                }
            }
            return false;
        }
    }
}
