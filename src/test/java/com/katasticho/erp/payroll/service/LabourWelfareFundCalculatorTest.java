package com.katasticho.erp.payroll.service;

import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.repository.GstStateCodeRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.LwfRule;
import com.katasticho.erp.payroll.repository.LwfRuleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LabourWelfareFundCalculatorTest {

    @Mock private LwfRuleRepository lwfRuleRepository;
    @Mock private GstStateCodeRepository gstStateCodeRepository;
    @Mock private OrganisationRepository organisationRepository;

    private LabourWelfareFundCalculator calc;

    private final LocalDate april = LocalDate.of(2026, 4, 30);
    private final LocalDate june = LocalDate.of(2026, 6, 30);
    private final LocalDate december = LocalDate.of(2026, 12, 31);
    private final LocalDate march = LocalDate.of(2026, 3, 31);
    private final LocalDate september = LocalDate.of(2026, 9, 30);

    @BeforeEach
    void setUp() {
        calc = new LabourWelfareFundCalculator(
                lwfRuleRepository, gstStateCodeRepository, organisationRepository);
    }

    // ── Half-yearly Maharashtra: ONLY June + December ──────────────

    @Test
    void mh_collects_in_june_and_december_only_not_other_months() {
        when(lwfRuleRepository.findApplicable(eq("MH"), any()))
                .thenReturn(List.of(rule("MH", "HALF_YEARLY", "6,12", "25", "75")));

        var june = calc.calculate("MH", new BigDecimal("50000"), this.june);
        var december = calc.calculate("MH", new BigDecimal("50000"), this.december);
        var april = calc.calculate("MH", new BigDecimal("50000"), this.april);

        assertEquals(0, new BigDecimal("25").compareTo(june.employee()));
        assertEquals(0, new BigDecimal("75").compareTo(june.employer()));
        assertEquals(0, new BigDecimal("25").compareTo(december.employee()));
        assertEquals(0, april.employee().compareTo(BigDecimal.ZERO),
                "MH LWF must NOT be collected outside Jun/Dec");
        assertEquals(0, april.employer().compareTo(BigDecimal.ZERO));
    }

    // ── Annual Karnataka: only December ────────────────────────────

    @Test
    void ka_collects_only_in_december() {
        when(lwfRuleRepository.findApplicable(eq("KA"), any()))
                .thenReturn(List.of(rule("KA", "ANNUAL", "12", "20", "40")));

        var dec = calc.calculate("KA", new BigDecimal("50000"), december);
        var jun = calc.calculate("KA", new BigDecimal("50000"), june);

        assertEquals(0, new BigDecimal("20").compareTo(dec.employee()));
        assertEquals(0, new BigDecimal("40").compareTo(dec.employer()));
        assertEquals(0, jun.employee().compareTo(BigDecimal.ZERO));
    }

    // ── Monthly Kerala: every month ────────────────────────────────

    @Test
    void kerala_collects_every_month() {
        when(lwfRuleRepository.findApplicable(eq("KL"), any()))
                .thenReturn(List.of(rule("KL", "MONTHLY", "1,2,3,4,5,6,7,8,9,10,11,12", "45", "45")));

        for (int m = 1; m <= 12; m++) {
            var d = LocalDate.of(2026, m, 28);
            var c = calc.calculate("KL", new BigDecimal("50000"), d);
            assertEquals(0, new BigDecimal("45").compareTo(c.employee()),
                    "month " + m + " should collect");
        }
    }

    // ── Chhattisgarh: Mar + Sep, not Jun + Dec ─────────────────────

    @Test
    void chhattisgarh_uses_march_and_september_not_june_december() {
        when(lwfRuleRepository.findApplicable(eq("CG"), any()))
                .thenReturn(List.of(rule("CG", "HALF_YEARLY", "3,9", "15", "45")));

        assertTrue(calc.calculate("CG", new BigDecimal("50000"), march)
                .hasAny());
        assertTrue(calc.calculate("CG", new BigDecimal("50000"), september)
                .hasAny());
        assertFalse(calc.calculate("CG", new BigDecimal("50000"), june).hasAny(),
                "CG must skip Jun (it's Mar/Sep, not Jun/Dec)");
        assertFalse(calc.calculate("CG", new BigDecimal("50000"), december).hasAny(),
                "CG must skip Dec");
    }

    // ── Non-LWF state ──────────────────────────────────────────────

    @Test
    void uttar_pradesh_returns_zero_for_any_month() {
        when(lwfRuleRepository.findApplicable(eq("UP"), any())).thenReturn(List.of());

        for (var d : List.of(april, june, december, march)) {
            var c = calc.calculate("UP", new BigDecimal("50000"), d);
            assertFalse(c.hasAny(), "UP has no LWF — month " + d.getMonthValue());
        }
    }

    // ── Defensive ──────────────────────────────────────────────────

    @Test
    void null_or_blank_state_returns_zero_without_querying() {
        assertFalse(calc.calculate((String) null, new BigDecimal("50000"), june).hasAny());
        assertFalse(calc.calculate("", new BigDecimal("50000"), june).hasAny());
        assertFalse(calc.calculate("  ", new BigDecimal("50000"), june).hasAny());
    }

    @Test
    void null_period_end_returns_zero_without_querying() {
        assertFalse(calc.calculate("MH", new BigDecimal("50000"), null).hasAny());
    }

    @Test
    void collection_month_parser_tolerates_spaces_and_bad_tokens() {
        assertTrue(LabourWelfareFundCalculator.isCollectionMonth(" 6 , 12 ", 6));
        assertTrue(LabourWelfareFundCalculator.isCollectionMonth("abc, 9, xx", 9));
        assertFalse(LabourWelfareFundCalculator.isCollectionMonth("6,12", 5));
        assertFalse(LabourWelfareFundCalculator.isCollectionMonth("", 6));
        assertFalse(LabourWelfareFundCalculator.isCollectionMonth(null, 6));
    }

    // ── Org resolution ─────────────────────────────────────────────

    @Test
    void calculate_via_orgId_resolves_gst_code_to_alpha() {
        UUID orgId = UUID.randomUUID();
        Organisation org = new Organisation();
        org.setStateCode("27"); // Maharashtra
        GstStateCode mh = new GstStateCode();
        mh.setCode("27");
        mh.setAlphaCode("MH");

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(gstStateCodeRepository.findByCodeAndActiveTrue("27")).thenReturn(Optional.of(mh));
        when(lwfRuleRepository.findApplicable(eq("MH"), any()))
                .thenReturn(List.of(rule("MH", "HALF_YEARLY", "6,12", "25", "75")));

        var c = calc.calculate(orgId, new BigDecimal("50000"), june);
        assertEquals(0, new BigDecimal("25").compareTo(c.employee()));
        assertEquals(0, new BigDecimal("75").compareTo(c.employer()));
    }

    @Test
    void calculate_via_orgId_returns_zero_when_org_has_no_state() {
        UUID orgId = UUID.randomUUID();
        lenient().when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(new Organisation()));

        assertFalse(calc.calculate(orgId, new BigDecimal("50000"), june).hasAny());
    }

    private LwfRule rule(String state, String freq, String months,
                         String employee, String employer) {
        return LwfRule.builder()
                .id(UUID.randomUUID())
                .stateCode(state)
                .frequency(freq)
                .collectionMonths(months)
                .grossFrom(BigDecimal.ZERO)
                .employeeAmount(new BigDecimal(employee))
                .employerAmount(new BigDecimal(employer))
                .effectiveFrom(LocalDate.of(2024, 4, 1))
                .active(true)
                .build();
    }

    private static String eq(String s) {
        return org.mockito.ArgumentMatchers.eq(s);
    }
}
