package com.katasticho.erp.common.country;

import org.springframework.stereotype.Component;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Set;

/**
 * Oman — cheap adjacency to the UAE (same flat 5% VAT, same Gulf CoA + tax seed,
 * Arabic-first). Two things that differ and MUST be handled:
 *   • OMR uses THREE decimal places (1.000), not two — drives money rounding.
 *   • Weekend is Friday-Saturday (not Sat-Sun) — drives HR/payroll working days.
 */
@Component
public class OmanProfile implements CountryProfile {

    @Override public String code() { return "OM"; }
    @Override public String displayName() { return "Oman"; }
    @Override public String currencyCode() { return "OMR"; }
    @Override public int currencyDecimals() { return 3; }
    @Override public String defaultTimezone() { return "Asia/Muscat"; }
    @Override public List<String> defaultLocales() { return List.of("ar", "en"); }
    @Override public Set<DayOfWeek> weekendDays() { return Set.of(DayOfWeek.FRIDAY, DayOfWeek.SATURDAY); }
    @Override public int fiscalYearStartMonth() { return 1; }
    @Override public String taxIdLabel() { return "VAT No"; }
    // Reuse the Gulf CoA + VAT-5% tax seed (identical to UAE).
    @Override public String coaTemplateCountry() { return "AE"; }
    @Override public String taxSeedKey() { return "AE"; }
}
