package com.katasticho.erp.common.country;

import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Set;

/**
 * Kenya — third market (conditional, post-UAE). Flat 16% VAT, KES (2dp),
 * English + Swahili, Sat-Sun weekend, January fiscal year. Tax-id is the KRA PIN.
 *
 * <p>Note: Kenya's hard local dependencies (M-Pesa reconciliation, eTIMS
 * e-invoicing, complex PAYE/NSSF/SHIF payroll) are first-class work for the
 * Kenya phase — this profile only carries the country defaults.
 */
@Component
public class KenyaProfile implements CountryProfile {

    @Override public String code() { return "KE"; }
    @Override public String displayName() { return "Kenya"; }
    @Override public String currencyCode() { return "KES"; }
    @Override public int currencyDecimals() { return 2; }
    @Override public String defaultTimezone() { return "Africa/Nairobi"; }
    @Override public List<String> defaultLocales() { return List.of("en", "sw"); }
    @Override public Set<DayOfWeek> weekendDays() { return Set.of(DayOfWeek.SATURDAY, DayOfWeek.SUNDAY); }
    @Override public int fiscalYearStartMonth() { return 1; }
    @Override public String taxIdLabel() { return "PIN"; }
    @Override public String coaTemplateCountry() { return "KE"; }
    @Override public String taxSeedKey() { return "KE"; }
}
