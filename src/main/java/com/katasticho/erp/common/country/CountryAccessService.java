package com.katasticho.erp.common.country;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Resolves the current org's country and enforces {@link RequiresCountry}.
 *
 * <p>An org's country is immutable once set (locked after the first posted
 * invoice), so it is safe to cache {@code orgId → countryCode} in-process and
 * avoid a DB hit on every gated call. Mirrors {@code ModuleAccessService}.
 */
@Service
@RequiredArgsConstructor
public class CountryAccessService {

    private final OrganisationRepository organisationRepository;
    private final CountryRegistry countryRegistry;

    /** orgId → countryCode. Country never changes for an org → safe to cache. */
    private final ConcurrentHashMap<UUID, String> cache = new ConcurrentHashMap<>();

    /** Country code of the current tenant org, or "IN" if not resolvable. */
    public String currentCountry() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required",
                    "ORG_CONTEXT_REQUIRED", HttpStatus.FORBIDDEN);
        }
        return countryOf(orgId);
    }

    /** Country code for a specific org (cached), defaulting to "IN" if unset. */
    public String countryOf(UUID orgId) {
        return cache.computeIfAbsent(orgId, id ->
                organisationRepository.findById(id)
                        .map(Organisation::getCountryCode)
                        .filter(c -> c != null && !c.isBlank())
                        .map(String::toUpperCase)
                        .orElse("IN"));
    }

    /** Throws unless the current org's country is one of {@code allowed}. */
    public void requireCountry(String... allowed) {
        String country = currentCountry();
        boolean ok = Arrays.stream(allowed)
                .anyMatch(a -> a != null && a.equalsIgnoreCase(country));
        if (!ok) {
            throw new BusinessException(
                    "This feature is not available in your country (" + country + ")",
                    "FEATURE_NOT_AVAILABLE_IN_COUNTRY",
                    HttpStatus.FORBIDDEN);
        }
    }

    /** Convenience: is the current org in the given country? (no throw) */
    public boolean isCountry(String code) {
        return code != null && code.equalsIgnoreCase(currentCountry());
    }

    /**
     * Non-working weekend days for the current org's country. India/UAE = Sat+Sun;
     * Oman = Fri+Sat. Drives HR working-days, leave and payroll LOP so a Gulf org's
     * Friday is correctly treated as a day off.
     */
    public Set<DayOfWeek> weekendDays() {
        return countryRegistry.get(currentCountry()).weekendDays();
    }

    /** Whether {@code date} falls on the current org's weekend. */
    public boolean isWeekend(LocalDate date) {
        return weekendDays().contains(date.getDayOfWeek());
    }

    /** Drop a cached entry (e.g. if an admin corrects a country pre-first-invoice). */
    public void evict(UUID orgId) {
        cache.remove(orgId);
    }
}
