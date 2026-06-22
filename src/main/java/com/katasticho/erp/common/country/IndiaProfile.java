package com.katasticho.erp.common.country;

import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Set;

/**
 * India profile — reproduces exactly what {@code Organisation} already defaults to
 * (countryCode "IN", INR, Asia/Kolkata, fiscal-April), so wiring this in changes
 * nothing for existing orgs. This is the default profile when a country is unknown.
 */
@Component
public class IndiaProfile implements CountryProfile {

    @Override public String code() { return "IN"; }
    @Override public String displayName() { return "India"; }
    @Override public String currencyCode() { return "INR"; }
    @Override public int currencyDecimals() { return 2; }
    @Override public String defaultTimezone() { return "Asia/Kolkata"; }
    @Override public List<String> defaultLocales() { return List.of("en", "hi"); }
    @Override public Set<DayOfWeek> weekendDays() { return Set.of(DayOfWeek.SATURDAY, DayOfWeek.SUNDAY); }
    @Override public int fiscalYearStartMonth() { return 4; }
    @Override public String taxIdLabel() { return "GSTIN"; }
    @Override public String coaTemplateCountry() { return "IN"; }
    @Override public String taxSeedKey() { return "IN"; }
}
