package com.katasticho.erp.common.country;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Resolves a {@link CountryProfile} by country code. Spring injects every
 * {@link CountryProfile} bean and indexes them by {@link CountryProfile#code()}.
 *
 * <p>Unknown / null codes fall back to {@link IndiaProfile} — so any org without
 * an explicit country (every org today defaults to "IN") behaves exactly as it
 * does now.
 */
@Service
@Slf4j
public class CountryRegistry {

    private final Map<String, CountryProfile> byCode;
    private final CountryProfile fallback;

    public CountryRegistry(List<CountryProfile> profiles) {
        this.byCode = profiles.stream()
                .collect(Collectors.toMap(p -> p.code().toUpperCase(), Function.identity()));
        this.fallback = byCode.getOrDefault("IN", profiles.get(0));
        log.info("CountryRegistry initialised with {} profiles: {}", byCode.size(), byCode.keySet());
    }

    /** Profile for the given code, or the India fallback if unknown/null. */
    public CountryProfile get(String countryCode) {
        if (countryCode == null) return fallback;
        return byCode.getOrDefault(countryCode.toUpperCase(), fallback);
    }

    /** True if the code maps to a real (non-fallback) profile. */
    public boolean isSupported(String countryCode) {
        return countryCode != null && byCode.containsKey(countryCode.toUpperCase());
    }

    /** All supported country codes (for an onboarding picker). */
    public List<CountryProfile> all() {
        return List.copyOf(byCode.values());
    }
}
