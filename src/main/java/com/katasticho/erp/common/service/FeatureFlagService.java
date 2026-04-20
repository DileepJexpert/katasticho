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
        Set<String> enabled = getCachedEnabled(orgId);
        return enabled.contains(feature);
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
                .orElseGet(() -> OrgFeatureFlag.builder()
                        .orgId(orgId)
                        .feature(feature)
                        .build());
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
        flagRepository.deleteByOrgId(orgId);

        Map<String, Boolean> flags = buildFlagsForIndustry(industryCode);
        for (var entry : flags.entrySet()) {
            OrgFeatureFlag flag = OrgFeatureFlag.builder()
                    .orgId(orgId)
                    .feature(entry.getKey())
                    .enabled(entry.getValue())
                    .build();
            flagRepository.save(flag);
        }

        invalidateCache(orgId);
        log.info("Seeded {} feature flags for org {} (industry={})", flags.size(), orgId, industryCode);
    }

    private Map<String, Boolean> buildFlagsForIndustry(String industryCode) {
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

        if (industryCode == null) return flags;

        switch (industryCode) {
            case "PHARMACY", "AYURVEDIC" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true);
                flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "GROCERY", "SUPERMARKET", "FRUITS_VEG", "ORGANIC" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("MRP_PRICING", true);
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "ELECTRONICS", "MOBILE", "APPLIANCES", "LED", "CCTV" -> {
                flags.put("SERIAL_TRACKING", true);
                flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "HARDWARE", "PLUMBING", "ELECTRICAL", "PAINT", "BUILDING" -> {
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "GARMENTS", "FABRIC", "FOOTWEAR", "JEWELRY", "COSMETICS" -> {
                flags.put("SIZE_COLOR_VARIANTS", true);
            }
            case "FOOD", "BAKERY", "CATERING", "CLOUD_KITCHEN", "JUICE" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "AUTO_PARTS" -> {
                flags.put("SERIAL_TRACKING", true);
                flags.put("WARRANTY_MANAGEMENT", true);
            }
            case "PHARMA_MANUFACTURER" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
                flags.put("DRUG_SCHEDULE_FIELDS", true);
            }
            case "FOOD_MANUFACTURER" -> {
                flags.put("BATCH_TRACKING", true);
                flags.put("EXPIRY_TRACKING", true);
                flags.put("BOM_ASSEMBLY", true);
                flags.put("WEIGHT_BASED_BILLING", true);
            }
            case "GARMENT_MANUFACTURER" -> {
                flags.put("SIZE_COLOR_VARIANTS", true);
                flags.put("BOM_ASSEMBLY", true);
            }
            case "ELECTRONICS_MANUFACTURER" -> {
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
            if (members != null && !members.isEmpty()) {
                return members;
            }
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
