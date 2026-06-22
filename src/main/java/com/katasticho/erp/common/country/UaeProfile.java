package com.katasticho.erp.common.country;

import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Set;

/**
 * United Arab Emirates — the first expansion beachhead. Flat 5% VAT, AED (2dp),
 * Arabic-first bilingual, Sat-Sun weekend (UAE switched in 2022), January fiscal
 * year. Tax-id is the TRN (Tax Registration Number).
 */
@Component
public class UaeProfile implements CountryProfile {

    @Override public String code() { return "AE"; }
    @Override public String displayName() { return "United Arab Emirates"; }
    @Override public String currencyCode() { return "AED"; }
    @Override public int currencyDecimals() { return 2; }
    @Override public String defaultTimezone() { return "Asia/Dubai"; }
    @Override public List<String> defaultLocales() { return List.of("ar", "en"); }
    @Override public Set<DayOfWeek> weekendDays() { return Set.of(DayOfWeek.SATURDAY, DayOfWeek.SUNDAY); }
    @Override public int fiscalYearStartMonth() { return 1; }
    @Override public String taxIdLabel() { return "TRN"; }
    @Override public String coaTemplateCountry() { return "AE"; }
    @Override public String taxSeedKey() { return "AE"; }
}
