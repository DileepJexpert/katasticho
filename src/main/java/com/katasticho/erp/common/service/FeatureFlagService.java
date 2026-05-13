package com.katasticho.erp.common.service;

import com.katasticho.erp.common.entity.OrgFeatureFlag;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.repository.OrgFeatureFlagRepository;
import com.katasticho.erp.organisation.IndustryFeatureConfig;
import com.katasticho.erp.organisation.IndustryFeatureConfigRepository;
import com.katasticho.erp.organisation.IndustrySubCategoryRepository;
import com.katasticho.erp.organisation.IndustryTemplate;
import com.katasticho.erp.organisation.IndustryTemplateRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class FeatureFlagService {

    private final OrgFeatureFlagRepository flagRepository;
    private final StringRedisTemplate redisTemplate;
    private final IndustryTemplateRepository industryTemplateRepository;
    private final IndustrySubCategoryRepository subCategoryRepository;
    private final IndustryFeatureConfigRepository featureConfigRepository;
    private final OrganisationRepository organisationRepository;

    private static final String CACHE_PREFIX = "features:v2:";
    private static final Duration CACHE_TTL = Duration.ofHours(1);

    public boolean isEnabled(UUID orgId, String feature) {
        return getCachedEnabled(orgId).contains(feature);
    }

    public List<OrgFeatureFlag> listAll(UUID orgId) {
        return flagRepository.findByOrgId(orgId);
    }

    public List<String> listEnabled(UUID orgId) {
        return new ArrayList<>(getCachedEnabled(orgId));
    }

    @Transactional
    public void enable(UUID orgId, String feature) {
        OrgFeatureFlag flag = flagRepository.findByOrgIdAndFeature(orgId, feature)
                .orElseGet(() -> OrgFeatureFlag.builder().orgId(orgId).feature(feature).build());
        flag.setEnabled(true);
        flagRepository.save(flag);
        invalidateCache(orgId);
    }

    @Transactional
    public void disable(UUID orgId, String feature) {
        flagRepository.findByOrgIdAndFeature(orgId, feature).ifPresent(flag -> {
            flag.setEnabled(false);
            flagRepository.save(flag);
        });
        invalidateCache(orgId);
    }

    @Transactional
    public void seedForIndustry(UUID orgId, String industryCode) {
        seedForSubCategories(orgId, industryCode == null
                ? List.of("OTHER_RETAIL")
                : List.of(industryCode));
    }

    @Transactional
    public void seedForSubCategories(UUID orgId, List<String> subCategoryCodes) {
        flagRepository.deleteByOrgId(orgId);

        Map<String, Boolean> merged = defaultFlags();

        if (subCategoryCodes != null && !subCategoryCodes.isEmpty()) {
            UUID templateId = resolveTemplateId(subCategoryCodes);

            if (templateId != null) {
                // Apply module-level flags (INVENTORY, POS, etc.) from businessType
                industryTemplateRepository.findById(templateId)
                        .ifPresent(t -> applyModuleFlagsForTemplate(merged, t));

                // Apply default (template-level) feature flags (BATCH_TRACKING etc.)
                featureConfigRepository.findByIndustryTemplateIdAndSubCategoryCodeIsNull(templateId)
                        .ifPresent(cfg -> cfg.getFeatureFlags().forEach(f -> merged.put(f, true)));

                // Overlay sub-category-specific overrides
                List<IndustryFeatureConfig> subCatConfigs = featureConfigRepository
                        .findByIndustryTemplateIdAndSubCategoryCodeIn(templateId, subCategoryCodes);
                for (IndustryFeatureConfig cfg : subCatConfigs) {
                    cfg.getFeatureFlags().forEach(f -> merged.put(f, true));
                }
            } else {
                // Ultimate fallback for legacy / unknown codes not in DB
                for (String code : subCategoryCodes) {
                    flagsForSubCategoryFallback(code).forEach((f, enabled) -> {
                        if (enabled) merged.put(f, true);
                    });
                }
            }
        }

        for (var entry : merged.entrySet()) {
            flagRepository.save(OrgFeatureFlag.builder()
                    .orgId(orgId)
                    .feature(entry.getKey())
                    .enabled(entry.getValue())
                    .build());
        }

        invalidateCache(orgId);
        log.info("Seeded {} feature flags for org {} (subCategories={})",
                merged.size(), orgId, subCategoryCodes);
    }

    /**
     * Resolves the IndustryTemplate UUID for a list of codes.
     * Codes may be either sub-category codes (PHARMACY_CHAIN) or industry codes (PHARMACY).
     */
    private UUID resolveTemplateId(List<String> codes) {
        // Step 1: look up via IndustrySubCategory table (handles sub-category codes)
        for (String code : codes) {
            Optional<UUID> templateId = subCategoryRepository.findBySubCategoryCode(code)
                    .map(sc -> sc.getIndustryTemplateId());
            if (templateId.isPresent()) return templateId.get();
        }
        // Step 2: treat code as an industry code directly (handles industry-level codes)
        for (String code : codes) {
            Optional<UUID> templateId = industryTemplateRepository.findByIndustryCode(code)
                    .map(IndustryTemplate::getId);
            if (templateId.isPresent()) return templateId.get();
        }
        return null;
    }

    /**
     * Applies module-level flags (INVENTORY, POS, MANUFACTURING, PHARMA, BATCH_EXPIRY)
     * based on the industry template's businessType and industryCode.
     * These are separate from the fine-grained feature flags stored in IndustryFeatureConfig.
     */
    private void applyModuleFlagsForTemplate(Map<String, Boolean> merged, IndustryTemplate template) {
        switch (template.getBusinessType()) {
            case "RETAILER" -> {
                merged.put(ModuleCode.POS, true);
                merged.put(ModuleCode.INVENTORY, true);
            }
            case "DISTRIBUTOR" -> merged.put(ModuleCode.INVENTORY, true);
            case "MANUFACTURER" -> {
                merged.put(ModuleCode.INVENTORY, true);
                merged.put(ModuleCode.MANUFACTURING, true);
            }
            default -> { }
        }
        // Pharma-specific modules
        String ic = template.getIndustryCode();
        if (ic.contains("PHARMA") || ic.equals("PHARMACY")) {
            merged.put(ModuleCode.PHARMA, true);
            merged.put(ModuleCode.BATCH_EXPIRY, true);
        }
    }

    private Map<String, Boolean> defaultFlags() {
        Map<String, Boolean> flags = new LinkedHashMap<>();
        flags.put(ModuleCode.ACCOUNTING, true);
        flags.put(ModuleCode.AR, true);
        flags.put(ModuleCode.AP, true);
        flags.put(ModuleCode.GST, true);
        flags.put(ModuleCode.BANK_RECON, true);
        flags.put(ModuleCode.AI_INBOX, true);
        flags.put(ModuleCode.REPORTS, true);
        flags.put(ModuleCode.COLLECTIONS, true);
        flags.put(ModuleCode.PAYMENTS, true);
        // All modules default to enabled. The org owner/admin always has access
        // to every module; subscription/plan-based gating is a future concern.
        // Industry/sub-category only seeds fine-grained UX flags below.
        flags.put(ModuleCode.POS, true);
        flags.put(ModuleCode.INVENTORY, true);
        flags.put(ModuleCode.PHARMA, true);
        flags.put(ModuleCode.MANUFACTURING, true);
        flags.put(ModuleCode.RECURRING_BILLING, true);
        flags.put(ModuleCode.MULTI_ENTITY, true);
        flags.put(ModuleCode.BATCH_EXPIRY, true);
        flags.put("BATCH_TRACKING", false);
        flags.put("EXPIRY_TRACKING", false);
        flags.put("MRP_PRICING", false);
        flags.put("DRUG_SCHEDULE_FIELDS", false);
        flags.put("SERIAL_TRACKING", false);
        flags.put("WARRANTY_MANAGEMENT", false);
        flags.put("WEIGHT_BASED_BILLING", false);
        flags.put("SIZE_COLOR_VARIANTS", false);
        flags.put("BOM_ASSEMBLY", false);
        flags.put("MULTI_WAREHOUSE", false);
        flags.put("MULTI_BRANCH", false);
        return flags;
    }

    private Map<String, Boolean> flagsForSubCategoryFallback(String code) {
        Map<String, Boolean> flags = defaultFlags();
        if (code == null) return flags;
        switch (code) {
            case "ACCOUNTING_FIRM", "FINANCE_ERP", "SERVICE_BUSINESS" -> { }
            case "TRADING", "KIRANA", "OTHER_RETAIL", "RETAIL", "RETAILER", "DISTRIBUTOR" -> {
                flags.put(ModuleCode.POS, true); flags.put(ModuleCode.INVENTORY, true);
            }
            case "PHARMACY", "AYURVEDIC", "ALLOPATHIC_MEDICINE", "AYURVEDIC_HERBAL",
                 "SINGLE_MEDICAL_STORE", "MEDICAL_SHOP_CHAIN" -> {
                flags.put(ModuleCode.INVENTORY, true); flags.put(ModuleCode.PHARMA, true);
                flags.put(ModuleCode.BATCH_EXPIRY, true);
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true); flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "GROCERY", "SUPERMARKET", "FRUITS_VEG", "ORGANIC", "KIRANA_STORE",
                 "SUPERMARKET_CHAIN", "FRUITS_VEGETABLES", "ORGANIC_STORE" -> {
                flags.put(ModuleCode.POS, true); flags.put(ModuleCode.INVENTORY, true);
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true); flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "ELECTRONICS", "MOBILE", "APPLIANCES", "LED", "CCTV",
                 "COMPUTER_LAPTOP", "MOBILE_ACCESSORIES", "HOME_APPLIANCES",
                 "LED_LIGHTING", "CCTV_SECURITY" -> {
                flags.put(ModuleCode.POS, true); flags.put(ModuleCode.INVENTORY, true);
                flags.put("SERIAL_TRACKING", true); flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "GARMENTS", "FABRIC", "FOOTWEAR", "JEWELRY", "COSMETICS",
                 "READYMADE_GARMENTS", "FABRIC_STORE", "FOOTWEAR_SHOP",
                 "JEWELLERY_SHOP", "COSMETICS_BEAUTY" -> {
                flags.put(ModuleCode.POS, true); flags.put(ModuleCode.INVENTORY, true);
                flags.put("SIZE_COLOR_VARIANTS", true);
            }
            case "FOOD", "BAKERY", "CATERING", "CLOUD_KITCHEN", "JUICE",
                 "RESTAURANT", "BAKERY_CONFECTIONERY", "CATERING_SERVICE",
                 "CLOUD_KITCHEN_BRAND", "JUICE_BEVERAGE" -> {
                flags.put(ModuleCode.POS, true); flags.put(ModuleCode.INVENTORY, true);
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true); flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "PHARMA_MANUFACTURER", "ALLOPATHIC_MANUFACTURER" -> {
                flags.put(ModuleCode.INVENTORY, true); flags.put(ModuleCode.PHARMA, true);
                flags.put(ModuleCode.MANUFACTURING, true); flags.put(ModuleCode.BATCH_EXPIRY, true);
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true); flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "FOOD_MANUFACTURER", "FOOD_PROCESSING" -> {
                flags.put(ModuleCode.INVENTORY, true); flags.put(ModuleCode.MANUFACTURING, true);
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true); flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "GARMENT_MANUFACTURER", "APPAREL_MANUFACTURER" -> {
                flags.put(ModuleCode.INVENTORY, true); flags.put(ModuleCode.MANUFACTURING, true);
                flags.put("SIZE_COLOR_VARIANTS", true); flags.put("BOM_ASSEMBLY", true);
            }
            case "ELECTRONICS_MANUFACTURER", "ELECTRONICS_MFG" -> {
                flags.put(ModuleCode.INVENTORY, true); flags.put(ModuleCode.MANUFACTURING, true);
                flags.put("SERIAL_TRACKING", true); flags.put("BOM_ASSEMBLY", true);
                flags.put("WARRANTY_MANAGEMENT", true);
            }
            default -> { }
        }
        return flags;
    }

    private Set<String> getCachedEnabled(UUID orgId) {
        String key = CACHE_PREFIX + orgId;
        try {
            Set<String> members = redisTemplate.opsForSet().members(key);
            if (members != null && !members.isEmpty()) return members;
        } catch (Exception e) {
            log.debug("Redis cache miss for features:{}: {}", orgId, e.getMessage());
        }

        if (!flagRepository.existsByOrgId(orgId)) {
            lazySeedFlags(orgId);
        }

        List<OrgFeatureFlag> flags = flagRepository.findByOrgIdAndEnabledTrue(orgId);
        Set<String> enabled = flags.stream()
                .map(OrgFeatureFlag::getFeature)
                .collect(Collectors.toSet());

        if (!enabled.isEmpty()) {
            try {
                redisTemplate.opsForSet().add(key, enabled.toArray(new String[0]));
                redisTemplate.expire(key, CACHE_TTL);
            } catch (Exception e) {
                log.debug("Failed to cache features for org {}: {}", orgId, e.getMessage());
            }
        }

        return enabled;
    }

    public void invalidateCache(UUID orgId) {
        try {
            redisTemplate.delete(CACHE_PREFIX + orgId);
        } catch (Exception e) {
            log.debug("Failed to invalidate feature cache for org {}: {}", orgId, e.getMessage());
        }
    }

    private void lazySeedFlags(UUID orgId) {
        String industryCode = organisationRepository.findById(orgId)
                .map(org -> org.getIndustryCode())
                .orElse("OTHER_RETAIL");
        log.info("No feature flags found for org {} — lazy-seeding from industry code {}", orgId, industryCode);
        seedForIndustry(orgId, industryCode);
    }
}
