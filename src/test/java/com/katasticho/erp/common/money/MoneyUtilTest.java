package com.katasticho.erp.common.money;

import com.katasticho.erp.common.currency.entity.Currency;
import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MoneyUtilTest {

    @Mock private CurrencyRepository currencyRepository;

    private Currency cur(String code, int dp) {
        return Currency.builder().code(code).name(code).decimalPlaces(dp).build();
    }

    @Test
    void two_decimal_rounding_is_byte_identical_to_legacy_setScale2() {
        // The exact value the old setScale(2, HALF_UP) would produce.
        assertEquals(new BigDecimal("123.46"), MoneyUtil.round(new BigDecimal("123.455"), 2));
        assertEquals(new BigDecimal("123.45"), MoneyUtil.round(new BigDecimal("123.454"), 2));
    }

    @Test
    void three_decimal_for_gulf_dinars() {
        assertEquals(new BigDecimal("1.235"), MoneyUtil.round(new BigDecimal("1.2345"), 3));
    }

    @Test
    void zero_decimal_for_yen() {
        assertEquals(new BigDecimal("124"), MoneyUtil.round(new BigDecimal("123.5"), 0));
    }

    @Test
    void null_amount_is_null() {
        assertNull(MoneyUtil.round(null, 2));
    }

    @Test
    void precision_service_reads_currency_master_and_caches() {
        MoneyPrecisionService svc = new MoneyPrecisionService(currencyRepository, null);
        when(currencyRepository.findByCode("OMR")).thenReturn(Optional.of(cur("OMR", 3)));
        assertEquals(3, svc.decimalsFor("OMR"));
        assertEquals(3, svc.decimalsFor("omr")); // case-insensitive + cached
        verify(currencyRepository, times(1)).findByCode("OMR");
    }

    @Test
    void precision_service_defaults_unknown_currency_to_two() {
        MoneyPrecisionService svc = new MoneyPrecisionService(currencyRepository, null);
        lenient().when(currencyRepository.findByCode("ZZZ")).thenReturn(Optional.empty());
        assertEquals(2, svc.decimalsFor("ZZZ"));
        assertEquals(2, svc.decimalsFor(null));
        assertEquals(2, svc.decimalsFor("  "));
    }
}
