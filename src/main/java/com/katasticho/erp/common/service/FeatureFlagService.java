package com.katasticho.erp.common.service;

import com.katasticho.erp.common.entity.OrgFeatureFlag;
import com.katasticho.erp.common.repository.OrgFeatureFlagRepository;
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

        // Start with all flags OFF
        Map<String, Boolean> merged = defaultFlags();

        // OR-merge flags from each sub-category
        if (subCategoryCodes != null) {
            for (String code : subCategoryCodes) {
                Map<String, Boolean> subFlags = flagsForSubCategory(code);
                subFlags.forEach((feature, enabled) -> {
                    if (enabled) merged.put(feature, true);
                });
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

    private Map<String, Boolean> flagsForSubCategory(String code) {
        Map<String, Boolean> flags = defaultFlags();
        if (code == null) return flags;

        switch (code) {
            case "PHARMACY", "AYURVEDIC", "ALLOPATHIC_MEDICINE", "AYURVEDIC_HERBAL",
                 "SINGLE_MEDICAL_STORE", "MEDICAL_SHOP_CHAIN" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true);
                flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "NUTRACEUTICALS", "SURGICAL_CONSUMABLES", "SURGICAL_EQUIPMENT" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true);
                flags.put("SERIAL_TRACKING", true);
                flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "GROCERY", "SUPERMARKET", "FRUITS_VEG", "ORGANIC",
                 "KIRANA_STORE", "SUPERMARKET_CHAIN", "FRUITS_VEGETABLES", "ORGANIC_STORE" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true);
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "ELECTRONICS", "MOBILE", "APPLIANCES", "LED", "CCTV",
                 "COMPUTER_LAPTOP", "MOBILE_ACCESSORIES", "HOME_APPLIANCES",
                 "LED_LIGHTING", "CCTV_SECURITY" -> {
                flags.put("SERIAL_TRACKING", true);
                flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "HARDWARE", "PLUMBING", "ELECTRICAL", "PAINT", "BUILDING",
                 "HARDWARE_STORE", "PLUMBING_SANITARY", "ELECTRICAL_SHOP",
                 "PAINT_HARDWARE", "BUILDING_MATERIALS" -> {
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "GARMENTS", "FABRIC", "FOOTWEAR", "JEWELRY", "COSMETICS",
                 "READYMADE_GARMENTS", "FABRIC_STORE", "FOOTWEAR_SHOP",
                 "JEWELLERY_SHOP", "COSMETICS_BEAUTY" -> {
                flags.put("SIZE_COLOR_VARIANTS", true);
            }
            case "FOOD", "BAKERY", "CATERING", "CLOUD_KITCHEN", "JUICE",
                 "RESTAURANT", "BAKERY_CONFECTIONERY", "CATERING_SERVICE",
                 "CLOUD_KITCHEN_BRAND", "JUICE_BEVERAGE" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "AUTO_PARTS", "AUTO_PARTS_SHOP", "AUTOMOBILE_ACCESSORIES" -> {
                flags.put("SERIAL_TRACKING", true);
                flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "PHARMA_MANUFACTURER", "ALLOPATHIC_MANUFACTURER" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
                flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "NUTRACEUTICALS_MANUFACTURER" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
            }
            case "FOOD_MANUFACTURER", "FOOD_PROCESSING" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "GARMENT_MANUFACTURER", "APPAREL_MANUFACTURER" -> {
                flags.put("SIZE_COLOR_VARIANTS", true);
                flags.put("BOM_ASSEMBLY", true);
            }
            case "ELECTRONICS_MANUFACTURER", "ELECTRONICS_MFG" -> {
                flags.put("SERIAL_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
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
