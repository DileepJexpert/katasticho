package com.katasticho.erp.common.dto;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Objects;

/**
 * Value object that wraps a monetary amount with its currency.
 * NEVER pass raw BigDecimal for monetary values between methods.
 * This prevents currency ambiguity bugs when multi-currency activates in v3.
 */
public record MonetaryAmount(BigDecimal amount, String currency) {

    private static final int SCALE = 2;
    private static final RoundingMode ROUNDING = RoundingMode.HALF_UP;

    public MonetaryAmount {
        Objects.requireNonNull(amount, "amount must not be null");
        Objects.requireNonNull(currency, "currency must not be null");
        if (currency.length() != 3) {
            throw new IllegalArgumentException("currency must be ISO 4217 3-letter code, got: " + currency);
        }
        amount = amount.setScale(SCALE, ROUNDING);
    }

    // Factory methods
    public static MonetaryAmount inr(BigDecimal amount) {
        return new MonetaryAmount(amount, "INR");
    }

    public static MonetaryAmount inr(String amount) {
        return new MonetaryAmount(new BigDecimal(amount), "INR");
    }

    public static MonetaryAmount inr(long amount) {
        return new MonetaryAmount(BigDecimal.valueOf(amount), "INR");
    }

    public static MonetaryAmount of(BigDecimal amount, String currency) {
        return new MonetaryAmount(amount, currency);
    }

    public static MonetaryAmount zero(String currency) {
        return new MonetaryAmount(BigDecimal.ZERO, currency);
    }

    // Operations — assert same currency before performing arithmetic
    public MonetaryAmount add(MonetaryAmount other) {
        assertSameCurrency(other);
        return new MonetaryAmount(this.amount.add(other.amount), this.currency);
    }

    public MonetaryAmount subtract(MonetaryAmount other) {
        assertSameCurrency(other);
        return new MonetaryAmount(this.amount.subtract(other.amount), this.currency);
    }

    public MonetaryAmount multiply(BigDecimal factor) {
        return new MonetaryAmount(this.amount.multiply(factor).setScale(SCALE, ROUNDING), this.currency);
    }

    public MonetaryAmount negate() {
        return new MonetaryAmount(this.amount.negate(), this.currency);
    }

    public boolean isPositive() {
        return amount.compareTo(BigDecimal.ZERO) > 0;
    }

    public boolean isZero() {
        return amount.compareTo(BigDecimal.ZERO) == 0;
    }

    public boolean isNegative() {
        return amount.compareTo(BigDecimal.ZERO) < 0;
    }

    private void assertSameCurrency(MonetaryAmount other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException(
                    "Cannot operate on different currencies: " + this.currency + " vs " + other.currency);
        }
    }
}
