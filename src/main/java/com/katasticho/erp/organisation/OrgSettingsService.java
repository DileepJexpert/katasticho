package com.katasticho.erp.organisation;

import com.fasterxml.jackson.core.type.TypeReference;
import com.katasticho.erp.common.cache.CacheService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.*;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrgSettingsService {

    private final OrgSettingsRepository settingsRepo;
    private final CacheService cacheService;

    private static final String CACHE_PREFIX = "org:settings:";
    private static final Duration CACHE_TTL = Duration.ofHours(12);
    private static final TypeReference<Map<String, String>> MAP_TYPE = new TypeReference<>() {};

    // ── Reads ─────────────────────────────────────────────────────

    public String get(UUID orgId, String key, String defaultValue) {
        return getAll(orgId).getOrDefault(key, defaultValue);
    }

    @Transactional(readOnly = true)
    public Map<String, String> getAll(UUID orgId) {
        String cacheKey = CACHE_PREFIX + orgId;
        Optional<Map<String, String>> cached = cacheService.get(cacheKey, MAP_TYPE);
        if (cached.isPresent()) return cached.get();

        Map<String, String> settings = settingsRepo.findByOrgId(orgId).stream()
                .collect(Collectors.toMap(OrgSetting::getKey, OrgSetting::getValue));

        cacheService.put(cacheKey, settings, CACHE_TTL);
        return settings;
    }

    // ── Writes ────────────────────────────────────────────────────

    @Transactional
    public void set(UUID orgId, String key, String value) {
        OrgSetting setting = settingsRepo.findByOrgIdAndKey(orgId, key)
                .orElseGet(() -> OrgSetting.builder().orgId(orgId).key(key).build());
        setting.setValue(value);
        settingsRepo.save(setting);
        invalidateCache(orgId);
    }

    @Transactional
    public void setBulk(UUID orgId, Map<String, String> values) {
        values.forEach((key, value) -> {
            OrgSetting setting = settingsRepo.findByOrgIdAndKey(orgId, key)
                    .orElseGet(() -> OrgSetting.builder().orgId(orgId).key(key).build());
            setting.setValue(value);
            settingsRepo.save(setting);
        });
        invalidateCache(orgId);
    }

    @Transactional
    public void delete(UUID orgId, String key) {
        settingsRepo.deleteByOrgIdAndKey(orgId, key);
        invalidateCache(orgId);
    }

    // ── Bootstrap seeding ─────────────────────────────────────────

    @Transactional
    public void seedDefaults(UUID orgId, Organisation org) {
        if (settingsRepo.existsByOrgIdAndKey(orgId, "invoice.prefix")) {
            log.debug("[OrgSettings] Already seeded for org {}", orgId);
            return;
        }

        String bizType = org.getBusinessType() != null ? org.getBusinessType() : "RETAILER";
        boolean isRetail = "RETAILER".equals(bizType) || "DISTRIBUTOR".equals(bizType);
        boolean isService = "SERVICE_PROVIDER".equals(bizType);

        Map<String, String> defaults = new LinkedHashMap<>();

        // General
        defaults.put("org.currency", org.getBaseCurrency() != null ? org.getBaseCurrency() : "INR");
        defaults.put("org.timezone", org.getTimezone() != null ? org.getTimezone() : "Asia/Kolkata");
        defaults.put("org.fiscal_year_start", String.valueOf(org.getFiscalYearStart() != null ? org.getFiscalYearStart() : 4));
        defaults.put("org.date_format", "DD/MM/YYYY");
        defaults.put("org.decimal_places", "2");
        defaults.put("org.language", "en");

        // Auto-numbering
        defaults.put("invoice.prefix", isService ? "INV" : "INV");
        defaults.put("invoice.next_number", "1");
        defaults.put("invoice.pad_digits", "5");
        defaults.put("quotation.prefix", "QUO");
        defaults.put("quotation.next_number", "1");
        defaults.put("quotation.pad_digits", "5");
        defaults.put("purchase_order.prefix", "PO");
        defaults.put("purchase_order.next_number", "1");
        defaults.put("purchase_order.pad_digits", "5");
        defaults.put("receipt.prefix", "REC");
        defaults.put("receipt.next_number", "1");
        defaults.put("receipt.pad_digits", "5");
        defaults.put("grn.prefix", "GRN");
        defaults.put("grn.next_number", "1");
        defaults.put("grn.pad_digits", "5");

        // Invoice defaults
        defaults.put("invoice.due_days", isService ? "30" : "7");
        defaults.put("invoice.payment_terms", isService ? "Net 30" : "Net 7");
        defaults.put("invoice.show_bank_details", "true");
        defaults.put("invoice.show_signature", "false");
        defaults.put("invoice.show_terms", "true");
        defaults.put("invoice.default_notes", "");
        defaults.put("invoice.default_terms", "Goods once sold will not be taken back.");

        // POS settings
        defaults.put("pos.enabled", isRetail ? "true" : "false");
        defaults.put("pos.cash_rounding", "true");
        defaults.put("pos.print_on_save", "true");
        defaults.put("pos.default_customer", "WALK_IN");
        defaults.put("pos.barcode_scan", "true");

        // Tax defaults
        defaults.put("tax.regime", org.getTaxRegime() != null ? org.getTaxRegime() : "INDIA_GST");
        defaults.put("tax.inclusive_pricing", "false");

        // Inventory
        defaults.put("inventory.low_stock_alert", "true");
        defaults.put("inventory.negative_stock", "false");
        defaults.put("inventory.valuation_method", "FIFO");

        // Communication
        defaults.put("notifications.email_enabled", "false");
        defaults.put("notifications.whatsapp_enabled", "false");

        setBulk(orgId, defaults);
        log.info("[OrgSettings] Seeded {} default settings for org {}", defaults.size(), orgId);
    }

    // ── Internal ──────────────────────────────────────────────────

    private void invalidateCache(UUID orgId) {
        cacheService.evict(CACHE_PREFIX + orgId);
    }
}
