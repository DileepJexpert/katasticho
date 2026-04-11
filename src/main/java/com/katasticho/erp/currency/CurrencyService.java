package com.katasticho.erp.currency;

import com.katasticho.erp.common.dto.MonetaryAmount;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Currency conversion service interface.
 *
 * v1 implementation: SimpleCurrencyService (always returns 1.0 — everything is INR).
 * v3 implementation: LiveCurrencyService (fetches from exchange_rate table populated by daily job).
 */
public interface CurrencyService {

    /**
     * Convert an amount from one currency to another on a specific date.
     */
    BigDecimal convert(BigDecimal amount, String fromCurrency, String toCurrency, LocalDate date);

    /**
     * Get the exchange rate from one currency to another on a specific date.
     */
    BigDecimal getRate(String fromCurrency, String toCurrency, LocalDate date);

    /**
     * Convert a MonetaryAmount to the organisation's base currency.
     */
    MonetaryAmount toBaseCurrency(MonetaryAmount txnAmount, String baseCurrency, LocalDate date);
}
