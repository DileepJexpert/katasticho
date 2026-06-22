package com.katasticho.erp.common.country;

import org.junit.jupiter.api.Test;

import java.time.DayOfWeek;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CountryRegistryTest {

    private final CountryRegistry registry = new CountryRegistry(List.of(
            new IndiaProfile(), new UaeProfile(), new OmanProfile(), new KenyaProfile()));

    @Test
    void resolves_known_countries_case_insensitively() {
        assertEquals("AE", registry.get("ae").code());
        assertEquals("OM", registry.get("OM").code());
        assertEquals("India", registry.get("IN").displayName());
    }

    @Test
    void unknown_or_null_country_falls_back_to_india() {
        assertEquals("IN", registry.get("ZZ").code());
        assertEquals("IN", registry.get(null).code());
        assertFalse(registry.isSupported("ZZ"));
        assertTrue(registry.isSupported("AE"));
    }

    @Test
    void india_profile_matches_organisation_defaults_byte_for_byte() {
        // These MUST equal Organisation's hardcoded defaults so retrofitting
        // the profile changes nothing for existing orgs.
        CountryProfile in = registry.get("IN");
        assertEquals("INR", in.currencyCode());
        assertEquals(2, in.currencyDecimals());
        assertEquals("Asia/Kolkata", in.defaultTimezone());
        assertEquals(4, in.fiscalYearStartMonth());
        assertEquals("GSTIN", in.taxIdLabel());
    }

    @Test
    void oman_carries_the_two_assumptions_that_bite() {
        CountryProfile om = registry.get("OM");
        assertEquals(3, om.currencyDecimals(), "OMR is 3 decimal places");
        assertEquals(java.util.Set.of(DayOfWeek.FRIDAY, DayOfWeek.SATURDAY), om.weekendDays(),
                "Oman weekend is Fri-Sat");
        // Oman reuses the Gulf CoA + VAT seed.
        assertEquals("AE", om.coaTemplateCountry());
        assertEquals("AE", om.taxSeedKey());
    }

    @Test
    void uae_is_vat5_aed_arabic_january() {
        CountryProfile ae = registry.get("AE");
        assertEquals("AED", ae.currencyCode());
        assertEquals(1, ae.fiscalYearStartMonth());
        assertEquals("TRN", ae.taxIdLabel());
        assertEquals(List.of("ar", "en"), ae.defaultLocales());
    }
}
