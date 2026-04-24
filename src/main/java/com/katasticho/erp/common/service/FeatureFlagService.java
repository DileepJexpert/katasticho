package com.katasticho.erp.common.service;

import com.katasticho.erp.common.entity.OrgFeatureFlag;
import com.katasticho.erp.common.repository.OrgFeatureFlagRepository;
import com.katasticho.erp.organisation.IndustryFeatureConfig;
import com.katasticho.erp.organisation.IndustryFeatureConfigRepository;
import com.katasticho.erp.organisation.IndustryTemplateRepository;
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
    private final IndustryFeatureConfigRepository featureConfigRepository;

    private static final String CACHE_PREFIX = "features:";
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

    /**
     * Seeds feature flags for an org based on one or more sub-category codes.
     * Flags from all sub-categories are merged with OR logic — if any sub-category
     * enables a flag, the flag is enabled.
     */
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

        // Look up template-level default config using the first sub-category code to find the template
        if (subCategoryCodes != null && !subCategoryCodes.isEmpty()) {
            // Find the industry template that owns any of these sub-category codes
            // Use the sub-category configs from the DB; fall back to hardcoded defaults only if DB is empty
            List<IndustryFeatureConfig> dbConfigs = featureConfigRepository
                    .findByIndustryTemplateIdAndSubCategoryCodeIn(resolveTemplateId(subCategoryCodes), subCategoryCodes);

            if (!dbConfigs.isEmpty()) {
                for (IndustryFeatureConfig cfg : dbConfigs) {
                    if (cfg.getFeatureFlags() != null) {
                        cfg.getFeatureFlags().forEach(f -> merged.put(f, true));
                    }
                }
            } else {
                // DB not yet seeded — fall back to legacy hardcoded logic (will become dead code once seeded)
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

    private UUID resolveTemplateId(List<String> subCategoryCodes) {
        // Find which template contains at least one of these sub-category codes
        for (String code : subCategoryCodes) {
            Optional<IndustryFeatureConfig> cfg = featureConfigRepository
                    .findAll().stream()
                    .filter(c -> code.equals(c.getSubCategoryCode()))
                    .findFirst();
            if (cfg.isPresent()) return cfg.get().getIndustryTemplateId();
        }
        // Fallback: try industryCode as a direct template lookup
        return industryTemplateRepository.findByIndustryCode(subCategoryCodes.get(0))
                .map(t -> t.getId())
                .orElse(UUID.randomUUID()); // will produce empty list in subsequent query
    }

    private Map<String, Boolean> defaultFlags() {
        Map<String, Boolean> flags = new LinkedHashMap<>();
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
            case "PHARMACY", "AYURVEDIC", "ALLOPATHIC_MEDICINE", "AYURVEDIC_HERBAL",
                 "SINGLE_MEDICAL_STORE", "MEDICAL_SHOP_CHAIN" -> {
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true); flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "GROCERY", "SUPERMARKET", "FRUITS_VEG", "ORGANIC", "KIRANA_STORE",
                 "SUPERMARKET_CHAIN", "FRUITS_VEGETABLES", "ORGANIC_STORE" -> {
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true); flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "ELECTRONICS", "MOBILE", "APPLIANCES", "LED", "CCTV",
                 "COMPUTER_LAPTOP", "MOBILE_ACCESSORIES", "HOME_APPLIANCES",
                 "LED_LIGHTING", "CCTV_SECURITY" -> {
                flags.put("SERIAL_TRACKING", true); flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "GARMENTS", "FABRIC", "FOOTWEAR", "JEWELRY", "COSMETICS",
                 "READYMADE_GARMENTS", "FABRIC_STORE", "FOOTWEAR_SHOP",
                 "JEWELLERY_SHOP", "COSMETICS_BEAUTY" -> {
                flags.put("SIZE_COLOR_VARIANTS", true);
            }
            case "FOOD", "BAKERY", "CATERING", "CLOUD_KITCHEN", "JUICE",
                 "RESTAURANT", "BAKERY_CONFECTIONERY", "CATERING_SERVICE",
                 "CLOUD_KITCHEN_BRAND", "JUICE_BEVERAGE" -> {
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true); flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "PHARMA_MANUFACTURER", "ALLOPATHIC_MANUFACTURER" -> {
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true); flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "FOOD_MANUFACTURER", "FOOD_PROCESSING" -> {
                flags.put("BATCH_TRACKING", true); flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true); flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "GARMENT_MANUFACTURER", "APPAREL_MANUFACTURER" -> {
                flags.put("SIZE_COLOR_VARIANTS", true); flags.put("BOM_ASSEMBLY", true);
            }
            case "ELECTRONICS_MANUFACTURER", "ELECTRONICS_MFG" -> {
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
}
