package com.katasticho.erp.common.money;

import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Resolves the minor-unit precision (decimal places) for a currency from the
 * {@code currency} master ({@code Currency.decimalPlaces}). Cached — currency
 * precision is effectively constant.
 *
 * <p>Unknown currency → 2 (the safe global default, and what every existing
 * posting site already assumes). So wiring this in never changes INR/AED math.
 */
@Service
@RequiredArgsConstructor
public class MoneyPrecisionService {

    private static final int DEFAULT_DECIMALS = 2;

    private final CurrencyRepository currencyRepository;
    private final OrganisationRepository organisationRepository;
    private final ConcurrentHashMap<String, Integer> codeCache = new ConcurrentHashMap<>();
    /** orgId → decimals; org base_currency is effectively constant after signup. */
    private final ConcurrentHashMap<UUID, Integer> orgCache = new ConcurrentHashMap<>();

    /** Decimal places for an ISO currency code (e.g. "OMR" → 3, "INR" → 2). */
    public int decimalsFor(String currencyCode) {
        if (currencyCode == null || currencyCode.isBlank()) return DEFAULT_DECIMALS;
        return codeCache.computeIfAbsent(currencyCode.toUpperCase(), code ->
                currencyRepository.findByCode(code)
                        .map(c -> c.getDecimalPlaces())
                        .orElse(DEFAULT_DECIMALS));
    }

    /**
     * Decimal places for the org's base currency. Resolves
     * {@code organisation.base_currency → currency.decimal_places}; defaults
     * to 2 if the org or currency lookup fails. Cached per org.
     */
    public int decimalsForOrg(UUID orgId) {
        if (orgId == null) return DEFAULT_DECIMALS;
        return orgCache.computeIfAbsent(orgId, id ->
                organisationRepository.findById(id)
                        .map(Organisation::getBaseCurrency)
                        .map(this::decimalsFor)
                        .orElse(DEFAULT_DECIMALS));
    }

    /** Drop a cached entry (e.g. if an admin corrects base_currency pre-first-invoice). */
    public void evictOrg(UUID orgId) {
        orgCache.remove(orgId);
    }
}
