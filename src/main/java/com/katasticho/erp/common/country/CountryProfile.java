package com.katasticho.erp.common.country;

import java.time.DayOfWeek;
import java.util.List;
import java.util.Set;

/**
 * Per-country defaults applied ONCE at signup (then editable per-org). This is the
 * "select country → everything populates" mechanism: {@code OrgBootstrapService}
 * resolves the org's {@link CountryProfile} via {@link CountryRegistry} and seeds
 * the chart of accounts, tax groups, locale, weekend, and fiscal year from it.
 *
 * <p>Each field below maps to a concrete internationalization gap documented in
 * {@code docs/INTERNATIONALIZATION_PLAN.md}. Implementations are Spring beans
 * ({@link IndiaProfile}, {@link UaeProfile}, …) indexed by {@link #code()}.
 *
 * <p>{@link IndiaProfile} reproduces the values {@code Organisation} already
 * defaults to (IN / INR / Asia/Kolkata / fiscal-April), so retrofitting it is
 * byte-for-byte identical to today's behaviour.
 */
public interface CountryProfile {

    /** ISO-3166 alpha-2 code, e.g. "IN", "AE", "OM", "KE". */
    String code();

    /** Human display name, e.g. "India". */
    String displayName();

    /** Base currency ISO code, e.g. "INR", "AED", "OMR". */
    String currencyCode();

    /**
     * Currency minor-unit precision. INR/AED/KES = 2, OMR/BHD/KWD = 3, JPY = 0.
     * Drives money rounding (see {@code MoneyUtil}) so OMR posts at 3 decimals.
     */
    int currencyDecimals();

    /** IANA timezone, e.g. "Asia/Kolkata", "Asia/Dubai". */
    String defaultTimezone();

    /** Preferred locales in priority order, e.g. ["en","hi"] or ["ar","en"]. */
    List<String> defaultLocales();

    /** Non-working days. India/UAE = Sat+Sun; Oman = Fri+Sat. Drives HR/payroll. */
    Set<DayOfWeek> weekendDays();

    /** Fiscal year start month (1-12). India = 4 (April); Gulf/Kenya = 1 (Jan). */
    int fiscalYearStartMonth();

    /** Tax-id label shown on org/contact forms: "GSTIN" / "TRN" / "VAT No" / "PIN". */
    String taxIdLabel();

    /**
     * Which {@code coa_template.country} rows to seed for this country.
     * Oman reuses the Gulf ("AE") template since both run flat 5% VAT.
     */
    String coaTemplateCountry();

    /**
     * The key {@code TaxSeedService} switches on to seed tax groups/rates.
     */
    String taxSeedKey();

    /**
     * Value stamped on {@code organisation.tax_regime} at signup. Everything
     * outside India runs a VAT-shaped regime; India overrides to INDIA_GST.
     */
    default String taxRegime() { return "VAT"; }
}
