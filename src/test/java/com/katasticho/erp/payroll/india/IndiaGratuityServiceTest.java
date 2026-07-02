package com.katasticho.erp.payroll.india;

import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Pure-math tests for the India gratuity formula (Payment of Gratuity Act
 * 1972). No mocks — {@link IndiaGratuityService#compute} and
 * {@link IndiaGratuityService#monthlyAccrual} touch no repository.
 */
class IndiaGratuityServiceTest {

    private final Clock clock = Clock.fixed(
            LocalDate.of(2026, 7, 2).atStartOfDay(ZoneId.systemDefault()).toInstant(),
            ZoneId.systemDefault());

    private final IndiaGratuityService svc = new IndiaGratuityService(
            null, null, null, null, null, null, clock);

    private static final BigDecimal BASIC_DA_26K = new BigDecimal("26000");

    @Test
    void under_5_years_is_not_eligible_and_pays_zero() {
        LocalDate from = LocalDate.of(2022, 1, 1);
        LocalDate to = LocalDate.of(2026, 1, 1); // 4.0 years
        IndiaGratuityResult r = svc.compute(from, to, BASIC_DA_26K);

        assertThat(r.eligible()).isFalse();
        assertThat(r.gratuityAmount()).isEqualByComparingTo("0");
        assertThat(r.cappedAmount()).isEqualByComparingTo("0");
        assertThat(r.formula()).contains("under 5");
    }

    @Test
    void exactly_five_years_uses_15_over_26_times_five() {
        // 26000 × 15/26 × 5 = 75000.00
        LocalDate from = LocalDate.of(2021, 1, 1);
        LocalDate to = LocalDate.of(2026, 1, 1); // exactly 5.0 years
        IndiaGratuityResult r = svc.compute(from, to, BASIC_DA_26K);

        assertThat(r.eligible()).isTrue();
        assertThat(r.completedYears()).isEqualTo(5);
        assertThat(r.gratuityAmount()).isEqualByComparingTo("75000.00");
        assertThat(r.cappedAmount()).isEqualByComparingTo("75000.00");
    }

    @Test
    void section_4_2_rounds_up_a_final_year_of_six_months_or_more() {
        // 7 years 7 months -> §4(2) rounds to 8 completed years
        // 26000 × 15/26 × 8 = 120000.00
        LocalDate from = LocalDate.of(2018, 1, 1);
        LocalDate to = LocalDate.of(2025, 8, 1); // 7 years 7 months
        IndiaGratuityResult r = svc.compute(from, to, BASIC_DA_26K);

        assertThat(r.completedYears()).isEqualTo(8);
        assertThat(r.gratuityAmount()).isEqualByComparingTo("120000.00");
    }

    @Test
    void section_4_2_does_not_round_a_final_year_under_six_months() {
        // 7 years 5 months -> stays 7 completed years
        // 26000 × 15/26 × 7 = 105000.00
        LocalDate from = LocalDate.of(2018, 1, 1);
        LocalDate to = LocalDate.of(2025, 6, 1); // 7 years 5 months
        IndiaGratuityResult r = svc.compute(from, to, BASIC_DA_26K);

        assertThat(r.completedYears()).isEqualTo(7);
        assertThat(r.gratuityAmount()).isEqualByComparingTo("105000.00");
    }

    @Test
    void statutory_ceiling_caps_the_payout_at_twenty_lakh() {
        // A large wage over many years exceeds ₹20,00,000
        // 200000 × 15/26 × 30 = 3,461,538.46 -> capped at 2,000,000
        LocalDate from = LocalDate.of(1996, 1, 1);
        LocalDate to = LocalDate.of(2026, 1, 1); // 30 years
        IndiaGratuityResult r = svc.compute(from, to, new BigDecimal("200000"));

        assertThat(r.gratuityAmount()).isEqualByComparingTo("3461538.46");
        assertThat(r.cappedAmount()).isEqualByComparingTo("2000000");
    }

    @Test
    void monthly_accrual_is_annual_gratuity_over_twelve() {
        // annual = 26000 × 15/26 = 15000; monthly = 15000/12 = 1250.00
        LocalDate join = LocalDate.of(2020, 1, 1);
        LocalDate asOf = LocalDate.of(2026, 6, 30);
        BigDecimal slice = svc.monthlyAccrual(join, asOf, BASIC_DA_26K, true);

        assertThat(slice).isEqualByComparingTo("1250.00");
    }

    @Test
    void monthly_accrual_defers_until_five_years_when_not_accruing_from_joining() {
        LocalDate join = LocalDate.of(2024, 1, 1);
        LocalDate asOf = LocalDate.of(2026, 6, 30); // ~2.5 years
        // vesting basis: nothing until 5 years
        assertThat(svc.monthlyAccrual(join, asOf, BASIC_DA_26K, false))
                .isEqualByComparingTo("0");
        // accrue-from-joining basis: full slice from day one
        assertThat(svc.monthlyAccrual(join, asOf, BASIC_DA_26K, true))
                .isEqualByComparingTo("1250.00");
    }

    @Test
    void monthly_accrual_returns_zero_on_bad_inputs() {
        LocalDate join = LocalDate.of(2020, 1, 1);
        LocalDate asOf = LocalDate.of(2026, 6, 30);
        assertThat(svc.monthlyAccrual(null, asOf, BASIC_DA_26K, true)).isEqualByComparingTo("0");
        assertThat(svc.monthlyAccrual(join, asOf, BigDecimal.ZERO, true)).isEqualByComparingTo("0");
        assertThat(svc.monthlyAccrual(join, join.minusDays(1), BASIC_DA_26K, true))
                .isEqualByComparingTo("0");
    }

    @Test
    void compute_rejects_bad_range_and_non_positive_wage() {
        LocalDate from = LocalDate.of(2020, 1, 1);
        assertThatThrownBy(() -> svc.compute(from, from, BASIC_DA_26K))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "GRATUITY_INVALID_RANGE");
        assertThatThrownBy(() -> svc.compute(from, LocalDate.of(2026, 1, 1), BigDecimal.ZERO))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "GRATUITY_NO_BASIC");
    }
}
