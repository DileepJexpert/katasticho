package com.katasticho.erp.common.currency.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.currency.entity.Currency;
import com.katasticho.erp.common.currency.entity.ExchangeRate;
import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import com.katasticho.erp.common.currency.repository.ExchangeRateRepository;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Manages currencies and exchange rates.
 * Named CurrencyManagementService to avoid conflict with the existing CurrencyService interface.
 */
@Service
@RequiredArgsConstructor
public class CurrencyManagementService {

    private static final MathContext MC = new MathContext(10, RoundingMode.HALF_UP);

    private final CurrencyRepository currencyRepo;
    private final ExchangeRateRepository exchangeRateRepo;

    // ── Currencies ──────────────────────────────────────────────────────────

    /**
     * List all active currencies (platform-wide, no org filter).
     */
    public List<Currency> listCurrencies() {
        return currencyRepo.findByIsActiveTrue();
    }

    // ── Exchange Rates ───────────────────────────────────────────────────────

    /**
     * Get the exchange rate from {@code from} to {@code to} on or before {@code date}.
     * If same currency, returns 1. Throws if no rate found.
     */
    public BigDecimal getExchangeRate(String from, String to, LocalDate date) {
        if (from.equalsIgnoreCase(to)) {
            return BigDecimal.ONE;
        }
        UUID orgId = TenantContext.getCurrentOrgId();
        return exchangeRateRepo.findLatestRate(orgId, from.toUpperCase(), to.toUpperCase(), date)
                .map(ExchangeRate::getRate)
                .orElseThrow(() -> new BusinessException(
                        "No exchange rate found for " + from + " → " + to + " on or before " + date,
                        "CURRENCY_RATE_NOT_FOUND",
                        HttpStatus.NOT_FOUND));
    }

    /**
     * Upsert the exchange rate for a specific date (manual entry).
     */
    @Transactional
    public ExchangeRate setExchangeRate(String from, String to, BigDecimal rate, LocalDate effectiveDate) {
        if (rate == null || rate.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Exchange rate must be positive", "CURRENCY_INVALID_RATE");
        }
        UUID orgId = TenantContext.getCurrentOrgId();
        String fromUpper = from.toUpperCase();
        String toUpper   = to.toUpperCase();

        ExchangeRate existing = exchangeRateRepo
                .findByOrgIdAndFromCurrencyAndToCurrencyAndEffectiveDateAndIsDeletedFalse(
                        orgId, fromUpper, toUpper, effectiveDate)
                .orElse(null);

        if (existing != null) {
            existing.setRate(rate);
            return exchangeRateRepo.save(existing);
        }

        ExchangeRate er = ExchangeRate.builder()
                .fromCurrency(fromUpper)
                .toCurrency(toUpper)
                .rate(rate)
                .effectiveDate(effectiveDate)
                .source("MANUAL")
                .build();
        return exchangeRateRepo.save(er);
    }

    /**
     * Convert {@code amount} from {@code from} to {@code to} using the rate on/before {@code date}.
     */
    public BigDecimal convert(BigDecimal amount, String from, String to, LocalDate date) {
        if (amount == null) {
            return BigDecimal.ZERO;
        }
        BigDecimal rate = getExchangeRate(from, to, date);
        return amount.multiply(rate, MC).setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * List all exchange rates for a base currency for the current org.
     */
    public List<ExchangeRate> listRates(String baseCurrency) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return exchangeRateRepo.findAllForBase(orgId, baseCurrency.toUpperCase());
    }
}
