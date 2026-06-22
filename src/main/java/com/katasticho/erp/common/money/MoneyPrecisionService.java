package com.katasticho.erp.common.money;

import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

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
    private final ConcurrentHashMap<String, Integer> cache = new ConcurrentHashMap<>();

    /** Decimal places for an ISO currency code (e.g. "OMR" → 3, "INR" → 2). */
    public int decimalsFor(String currencyCode) {
        if (currencyCode == null || currencyCode.isBlank()) return DEFAULT_DECIMALS;
        return cache.computeIfAbsent(currencyCode.toUpperCase(), code ->
                currencyRepository.findByCode(code)
                        .map(c -> c.getDecimalPlaces())
                        .orElse(DEFAULT_DECIMALS));
    }
}
