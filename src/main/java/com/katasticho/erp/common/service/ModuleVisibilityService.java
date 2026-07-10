package com.katasticho.erp.common.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.organisation.OrgSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Per-org authoritative module-visibility overrides.
 *
 * <p>The industry defaults + feature flags decide the baseline of which modules
 * an org sees. This layer lets an OWNER/ADMIN override that baseline per module,
 * in BOTH directions — show a module their vertical hides by default, or hide
 * one it shows — and the explicit decision WINS (the frontend applies it on top
 * of the computed capabilities). Absence of an override for a module means "use
 * the default", so this never changes behaviour for an org that hasn't touched it.
 *
 * <p>Stored as a single JSON object {@code {"PAYROLL": false, ...}} in
 * {@code org_settings} under {@link #KEY}, so it is org-scoped by construction —
 * one org's overrides can never affect another.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ModuleVisibilityService {

    /** org_settings key holding the JSON override map. */
    public static final String KEY = "modules.visibility";

    private static final Set<String> VALID_MODULES = Set.copyOf(ModuleCode.ALL);
    private static final TypeReference<LinkedHashMap<String, Boolean>> MAP_TYPE =
            new TypeReference<>() {};

    private final OrgSettingsService settingsService;
    private final ObjectMapper objectMapper;

    /** The org's override map (module code → visible). Empty when unset/invalid. */
    public Map<String, Boolean> getOverrides(UUID orgId) {
        String raw = settingsService.get(orgId, KEY, null);
        if (raw == null || raw.isBlank()) {
            return new LinkedHashMap<>();
        }
        try {
            Map<String, Boolean> parsed = objectMapper.readValue(raw, MAP_TYPE);
            // Defensive: drop any stale/unknown keys so a renamed module can't
            // linger and confuse the UI.
            LinkedHashMap<String, Boolean> clean = new LinkedHashMap<>();
            parsed.forEach((k, v) -> {
                if (k != null && v != null && VALID_MODULES.contains(k.toUpperCase())) {
                    clean.put(k.toUpperCase(), v);
                }
            });
            return clean;
        } catch (Exception e) {
            log.warn("Malformed modules.visibility for org {} — treating as empty: {}", orgId, e.getMessage());
            return new LinkedHashMap<>();
        }
    }

    /** Set (or replace) one module's visibility override. */
    public Map<String, Boolean> setOverride(UUID orgId, String module, boolean visible) {
        String code = normalize(module);
        Map<String, Boolean> overrides = getOverrides(orgId);
        overrides.put(code, visible);
        persist(orgId, overrides);
        return overrides;
    }

    /** Remove one module's override → that module reverts to the industry default. */
    public Map<String, Boolean> clearOverride(UUID orgId, String module) {
        String code = normalize(module);
        Map<String, Boolean> overrides = getOverrides(orgId);
        overrides.remove(code);
        persist(orgId, overrides);
        return overrides;
    }

    /** Replace the whole override map (validated). */
    public Map<String, Boolean> setAll(UUID orgId, Map<String, Boolean> requested) {
        LinkedHashMap<String, Boolean> clean = new LinkedHashMap<>();
        if (requested != null) {
            requested.forEach((k, v) -> {
                if (v != null) {
                    clean.put(normalize(k), v);
                }
            });
        }
        persist(orgId, clean);
        return clean;
    }

    /** Clear all overrides → the whole org reverts to its industry/flag defaults. */
    public void reset(UUID orgId) {
        persist(orgId, new LinkedHashMap<>());
    }

    private void persist(UUID orgId, Map<String, Boolean> overrides) {
        try {
            settingsService.set(orgId, KEY, objectMapper.writeValueAsString(overrides));
        } catch (Exception e) {
            throw new BusinessException("Failed to save module visibility",
                    "MODULE_VISIBILITY_SAVE_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private String normalize(String module) {
        String code = module == null ? "" : module.trim().toUpperCase();
        if (!VALID_MODULES.contains(code)) {
            throw new BusinessException("Unknown module code: " + module,
                    "MODULE_VISIBILITY_UNKNOWN_MODULE", HttpStatus.BAD_REQUEST);
        }
        return code;
    }
}
