package com.katasticho.erp.common.country;

import com.katasticho.erp.common.currency.entity.Currency;
import com.katasticho.erp.common.currency.repository.CurrencyRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CountryProfileControllerTest {

    @Mock private CountryAccessService countryAccessService;
    @Mock private CurrencyRepository currencyRepository;

    private final CountryRegistry registry = new CountryRegistry(List.of(
            new IndiaProfile(), new UaeProfile(), new OmanProfile(), new KenyaProfile()));

    private CountryProfileController controller() {
        return new CountryProfileController(countryAccessService, registry, currencyRepository);
    }

    @Test
    void uae_profile_renders_TRN_label_AED_and_january_fiscal() {
        when(countryAccessService.currentCountry()).thenReturn("AE");
        when(currencyRepository.findByCode("AED"))
                .thenReturn(Optional.of(Currency.builder().code("AED").name("Dirham")
                        .symbol("د.إ").decimalPlaces(2).build()));

        var body = controller().current().getBody().data();

        assertEquals("AE", body.countryCode());
        assertEquals("TRN", body.taxIdLabel());
        assertEquals("AED", body.currencyCode());
        assertEquals("د.إ", body.currencySymbol());
        assertEquals(2, body.currencyDecimals());
        assertEquals(1, body.fiscalYearStartMonth());
        assertEquals(List.of("ar", "en"), body.defaultLocales());
        assertEquals(List.of("SATURDAY", "SUNDAY"), body.weekendDays());
    }

    @Test
    void oman_renders_3dp_and_friday_saturday_weekend() {
        when(countryAccessService.currentCountry()).thenReturn("OM");
        when(currencyRepository.findByCode("OMR"))
                .thenReturn(Optional.of(Currency.builder().code("OMR").name("Rial")
                        .symbol("ر.ع.").decimalPlaces(3).build()));

        var body = controller().current().getBody().data();

        assertEquals(3, body.currencyDecimals());
        assertEquals(List.of("FRIDAY", "SATURDAY"), body.weekendDays());
    }

    @Test
    void india_renders_GSTIN_INR_and_april_fiscal() {
        when(countryAccessService.currentCountry()).thenReturn("IN");
        when(currencyRepository.findByCode("INR"))
                .thenReturn(Optional.of(Currency.builder().code("INR").name("Rupee")
                        .symbol("₹").decimalPlaces(2).build()));

        var body = controller().current().getBody().data();

        assertEquals("GSTIN", body.taxIdLabel());
        assertEquals("₹", body.currencySymbol());
        assertEquals(4, body.fiscalYearStartMonth());
    }

    @Test
    void falls_back_to_currency_code_when_symbol_missing() {
        when(countryAccessService.currentCountry()).thenReturn("KE");
        when(currencyRepository.findByCode("KES")).thenReturn(Optional.empty());

        var body = controller().current().getBody().data();

        assertEquals("KES", body.currencySymbol());
        assertEquals("PIN", body.taxIdLabel());
    }
}
