package com.katasticho.erp.payroll.gulf;

import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Pure-math tests for {@link GulfPayrollService#compute}. No mocks needed —
 * the formula does not touch any repository.
 *
 * <p>Reference: UAE Federal Decree-Law 33/2021 + Oman Labour Law 35/2003.
 */
class GulfPayrollServiceTest {

    private final Clock clock = Clock.fixed(
            LocalDate.of(2026, 6, 23).atStartOfDay(ZoneId.systemDefault()).toInstant(),
            ZoneId.systemDefault());

    /** Pure-math tests don't need any of the injected deps. */
    private final GulfPayrollService svc = new GulfPayrollService(
            null, null, (CountryAccessService) null, clock);

    private static final BigDecimal AED_10K = new BigDecimal("10000");

    @Test
    void uae_under_1_year_returns_zero() {
        LocalDate from = LocalDate.of(2025, 1, 1);
        LocalDate to = LocalDate.of(2025, 10, 1);  // ~9 months
        GratuityResult r = svc.compute("AE", from, to, AED_10K);

        assertThat(r.cappedGratuity()).isEqualByComparingTo("0");
        assertThat(r.formula()).contains("under 1 year");
    }

    @Test
    void uae_exactly_3_years_uses_21_day_tier_only() {
        // 21 days × 3 years × (10000 / 30) = 21000.00
        LocalDate from = LocalDate.of(2022, 1, 1);
        LocalDate to = LocalDate.of(2025, 1, 1);   // exactly 1095 days = 3.000 years
        GratuityResult r = svc.compute("AE", from, to, AED_10K);

        assertThat(r.dailyBasic()).isEqualByComparingTo("333.3333");
        assertThat(r.entitledDays()).isEqualByComparingTo("63.00");
        assertThat(r.cappedGratuity()).isEqualByComparingTo("21000.00");
    }

    @Test
    void uae_8_years_uses_21_for_first_5_plus_30_for_remaining_3() {
        // first 5 yrs × 21 = 105 days; next 3 yrs × 30 = 90 days; total 195 days
        // 195 × (10000/30) = 65000
        LocalDate from = LocalDate.of(2017, 1, 1);
        LocalDate to = LocalDate.of(2024, 12, 30);  // ~8 years
        GratuityResult r = svc.compute("AE", from, to, AED_10K);

        BigDecimal years = r.yearsExact();
        assertThat(years).isCloseTo(new BigDecimal("8"), org.assertj.core.data.Offset.offset(new BigDecimal("0.01")));
        // entitled = 5*21 + (years-5)*30
        BigDecimal expectedEntitled = new BigDecimal("5").multiply(new BigDecimal("21"))
                .add(years.subtract(new BigDecimal("5")).multiply(new BigDecimal("30")))
                .setScale(2, java.math.RoundingMode.HALF_UP);
        assertThat(r.entitledDays()).isEqualByComparingTo(expectedEntitled);
    }

    @Test
    void uae_caps_at_two_years_wage() {
        // 30 years × 30 days = 900 days = AED 300,000 of basic.
        // Cap = 24 × 10000 = 240,000. Should clip to 240000.
        LocalDate from = LocalDate.of(1995, 1, 1);
        LocalDate to = LocalDate.of(2025, 1, 1);   // 30 years
        GratuityResult r = svc.compute("AE", from, to, AED_10K);

        assertThat(r.grossGratuity()).isGreaterThan(new BigDecimal("240000"));
        assertThat(r.cappedGratuity()).isEqualByComparingTo("240000.00");
        assertThat(r.formula()).contains("capped");
    }

    @Test
    void oman_under_1_year_returns_zero() {
        LocalDate from = LocalDate.of(2025, 1, 1);
        LocalDate to = LocalDate.of(2025, 11, 1);  // ~10 months
        GratuityResult r = svc.compute("OM", from, to, new BigDecimal("600"));

        assertThat(r.cappedGratuity()).isEqualByComparingTo("0");
    }

    @Test
    void oman_exactly_2_years_uses_15_day_tier_only() {
        // 15 days × 2 yrs × (600/30) = 600
        LocalDate from = LocalDate.of(2023, 1, 1);
        LocalDate to = LocalDate.of(2025, 1, 1);   // exactly 2 yrs
        GratuityResult r = svc.compute("OM", from, to, new BigDecimal("600"));

        assertThat(r.entitledDays()).isEqualByComparingTo("30.00");
        assertThat(r.cappedGratuity()).isEqualByComparingTo("600.00");
    }

    @Test
    void oman_7_years_uses_15_for_first_3_plus_30_for_remaining_4() {
        // first 3 yrs × 15 = 45 days, next 4 yrs × 30 = 120 days; total 165 days
        // 165 × (600/30) = 3300
        LocalDate from = LocalDate.of(2018, 1, 1);
        LocalDate to = LocalDate.of(2024, 12, 30);  // ~7 years
        GratuityResult r = svc.compute("OM", from, to, new BigDecimal("600"));

        BigDecimal years = r.yearsExact();
        BigDecimal expectedEntitled = new BigDecimal("3").multiply(new BigDecimal("15"))
                .add(years.subtract(new BigDecimal("3")).multiply(new BigDecimal("30")))
                .setScale(2, java.math.RoundingMode.HALF_UP);
        assertThat(r.entitledDays()).isEqualByComparingTo(expectedEntitled);
    }

    @Test
    void unsupported_country_throws() {
        LocalDate from = LocalDate.of(2020, 1, 1);
        LocalDate to = LocalDate.of(2025, 1, 1);
        assertThatThrownBy(() -> svc.compute("KE", from, to, new BigDecimal("1000")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .isEqualTo("GRATUITY_UNSUPPORTED_COUNTRY"));
    }

    @Test
    void inverted_date_range_throws() {
        assertThatThrownBy(() -> svc.compute("AE",
                LocalDate.of(2025, 1, 1), LocalDate.of(2024, 1, 1), AED_10K))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .isEqualTo("GRATUITY_INVALID_RANGE"));
    }

    @Test
    void zero_basic_throws() {
        assertThatThrownBy(() -> svc.compute("AE",
                LocalDate.of(2020, 1, 1), LocalDate.of(2025, 1, 1), BigDecimal.ZERO))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .isEqualTo("GRATUITY_NO_BASIC"));
    }
}
