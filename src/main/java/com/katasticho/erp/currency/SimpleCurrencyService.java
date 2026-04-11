package com.katasticho.erp.currency;

import com.katasticho.erp.common.dto.MonetaryAmount;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * v1 implementation: everything is INR, rate is always 1.0.
 * In v3, this will be replaced by LiveCurrencyService that fetches real rates.
 */
@Service
public class SimpleCurrencyService implements CurrencyService {

    @Override
    public BigDecimal convert(BigDecimal amount, String fromCurrency, String toCurrency, LocalDate date) {
        // In v1, all amounts are INR. Rate = 1.0, conversion is identity.
        return amount;
    }

    @Override
    public BigDecimal getRate(String fromCurrency, String toCurrency, LocalDate date) {
        // In v1, always 1.0
        return BigDecimal.ONE;
    }

    @Override
    public MonetaryAmount toBaseCurrency(MonetaryAmount txnAmount, String baseCurrency, LocalDate date) {
        // In v1, txn currency = base currency = INR
        return txnAmount;
    }
}
