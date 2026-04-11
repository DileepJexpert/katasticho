package com.katasticho.erp.common.dto;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

class MonetaryAmountTest {

    @Test
    void shouldCreateInrAmount() {
        MonetaryAmount amount = MonetaryAmount.inr(new BigDecimal("1000.50"));
        assertEquals(new BigDecimal("1000.50"), amount.amount());
        assertEquals("INR", amount.currency());
    }

    @Test
    void shouldCreateFromLong() {
        MonetaryAmount amount = MonetaryAmount.inr(5000);
        assertEquals(new BigDecimal("5000.00"), amount.amount());
    }

    @Test
    void shouldCreateFromString() {
        MonetaryAmount amount = MonetaryAmount.inr("2500.75");
        assertEquals(new BigDecimal("2500.75"), amount.amount());
    }

    @Test
    void shouldAddSameCurrency() {
        MonetaryAmount a = MonetaryAmount.inr(1000);
        MonetaryAmount b = MonetaryAmount.inr(2500);
        MonetaryAmount result = a.add(b);
        assertEquals(new BigDecimal("3500.00"), result.amount());
        assertEquals("INR", result.currency());
    }

    @Test
    void shouldSubtractSameCurrency() {
        MonetaryAmount a = MonetaryAmount.inr(5000);
        MonetaryAmount b = MonetaryAmount.inr(2000);
        MonetaryAmount result = a.subtract(b);
        assertEquals(new BigDecimal("3000.00"), result.amount());
    }

    @Test
    void shouldMultiply() {
        MonetaryAmount amount = MonetaryAmount.inr(1000);
        MonetaryAmount result = amount.multiply(new BigDecimal("0.09"));
        assertEquals(new BigDecimal("90.00"), result.amount());
    }

    @Test
    void shouldRejectDifferentCurrencies() {
        MonetaryAmount inr = MonetaryAmount.inr(1000);
        MonetaryAmount usd = MonetaryAmount.of(new BigDecimal("100"), "USD");
        assertThrows(IllegalArgumentException.class, () -> inr.add(usd));
    }

    @Test
    void shouldRejectInvalidCurrencyCode() {
        assertThrows(IllegalArgumentException.class,
                () -> MonetaryAmount.of(new BigDecimal("100"), "US"));
    }

    @Test
    void shouldRejectNullAmount() {
        assertThrows(NullPointerException.class,
                () -> MonetaryAmount.inr((BigDecimal) null));
    }

    @Test
    void shouldNegate() {
        MonetaryAmount amount = MonetaryAmount.inr(1000);
        MonetaryAmount negated = amount.negate();
        assertEquals(new BigDecimal("-1000.00"), negated.amount());
    }

    @Test
    void shouldDetectPositiveZeroNegative() {
        assertTrue(MonetaryAmount.inr(100).isPositive());
        assertTrue(MonetaryAmount.zero("INR").isZero());
        assertTrue(MonetaryAmount.inr(-100).isNegative());
    }

    @Test
    void shouldScaleToTwoDecimalPlaces() {
        MonetaryAmount amount = MonetaryAmount.inr("100.999");
        assertEquals(new BigDecimal("101.00"), amount.amount());
    }
}
