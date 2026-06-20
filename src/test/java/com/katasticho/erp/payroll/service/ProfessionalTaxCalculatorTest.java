package com.katasticho.erp.payroll.service;

import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.repository.GstStateCodeRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PtSlab;
import com.katasticho.erp.payroll.repository.PtSlabRepository;
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
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

/**
 * Verifies PT slab selection per state on real seeded values. Uses the same
 * brackets as V3__pt_slab_state_master.sql so a slab edit there must update
 * these tests (intentional — that's the spec).
 */
@ExtendWith(MockitoExtension.class)
class ProfessionalTaxCalculatorTest {

    @Mock private PtSlabRepository ptSlabRepository;
    @Mock private GstStateCodeRepository gstStateCodeRepository;
    @Mock private OrganisationRepository organisationRepository;

    private ProfessionalTaxCalculator calc;

    private final LocalDate june = LocalDate.of(2026, 6, 30);
    private final LocalDate february = LocalDate.of(2026, 2, 28);

    @BeforeEach
    void setUp() {
        calc = new ProfessionalTaxCalculator(
                ptSlabRepository, gstStateCodeRepository, organisationRepository);
    }

    // ── Maharashtra: gender-split + Feb top-up ────────────────────

    @Test
    void mh_male_below_7500_is_nil() {
        when(ptSlabRepository.findApplicable("MH", "MALE", june)).thenReturn(mhMaleSlabs());

        BigDecimal pt = calc.calculate("MH", "MALE", new BigDecimal("6000"), june);
        assertEquals(0, pt.compareTo(BigDecimal.ZERO));
    }

    @Test
    void mh_male_7500_to_10000_is_175() {
        when(ptSlabRepository.findApplicable("MH", "MALE", june)).thenReturn(mhMaleSlabs());

        BigDecimal pt = calc.calculate("MH", "MALE", new BigDecimal("9500"), june);
        assertEquals(0, new BigDecimal("175.00").compareTo(pt));
    }

    @Test
    void mh_male_above_10000_is_200_in_june_and_300_in_february() {
        when(ptSlabRepository.findApplicable("MH", "MALE", june)).thenReturn(mhMaleSlabs());
        when(ptSlabRepository.findApplicable("MH", "MALE", february)).thenReturn(mhMaleSlabs());

        assertEquals(0, new BigDecimal("200.00")
                .compareTo(calc.calculate("MH", "MALE", new BigDecimal("50000"), june)));
        assertEquals(0, new BigDecimal("300.00")
                .compareTo(calc.calculate("MH", "MALE", new BigDecimal("50000"), february)));
    }

    @Test
    void mh_female_below_25000_is_nil_unlike_male() {
        when(ptSlabRepository.findApplicable("MH", "FEMALE", june)).thenReturn(mhFemaleSlabs());

        BigDecimal pt = calc.calculate("MH", "FEMALE", new BigDecimal("20000"), june);
        assertEquals(0, pt.compareTo(BigDecimal.ZERO));
    }

    @Test
    void unknown_gender_falls_back_to_male_bracket() {
        when(ptSlabRepository.findApplicable("MH", "MALE", june)).thenReturn(mhMaleSlabs());

        BigDecimal pt = calc.calculate("MH", "OTHER", new BigDecimal("9500"), june);
        assertEquals(0, new BigDecimal("175.00").compareTo(pt),
                "OTHER should default to MALE — the more conservative bracket");
    }

    // ── Karnataka: single threshold ────────────────────────────────

    @Test
    void ka_below_25000_is_nil_above_is_200() {
        when(ptSlabRepository.findApplicable(eq("KA"), anyString(), any()))
                .thenReturn(List.of(
                        slab(null, "0", "25000", "0", null),
                        slab(null, "25000.01", null, "200", null)));

        assertEquals(0, BigDecimal.ZERO
                .compareTo(calc.calculate("KA", "MALE", new BigDecimal("24000"), june)));
        assertEquals(0, new BigDecimal("200")
                .compareTo(calc.calculate("KA", "MALE", new BigDecimal("50000"), june)));
    }

    // ── West Bengal: graduated, no Feb top-up ──────────────────────

    @Test
    void wb_picks_middle_bracket() {
        when(ptSlabRepository.findApplicable(eq("WB"), anyString(), any()))
                .thenReturn(List.of(
                        slab(null, "0", "10000", "0", null),
                        slab(null, "10000.01", "15000", "110", null),
                        slab(null, "15000.01", "25000", "130", null),
                        slab(null, "25000.01", "40000", "150", null),
                        slab(null, "40000.01", null, "200", null)));

        assertEquals(0, new BigDecimal("130")
                .compareTo(calc.calculate("WB", null, new BigDecimal("20000"), june)));
    }

    // ── Non-PT state ───────────────────────────────────────────────

    @Test
    void delhi_returns_zero_for_any_gross() {
        when(ptSlabRepository.findApplicable("DL", "MALE", june)).thenReturn(List.of());

        BigDecimal pt = calc.calculate("DL", "MALE", new BigDecimal("500000"), june);
        assertEquals(0, pt.compareTo(BigDecimal.ZERO));
    }

    // ── Defensive paths ────────────────────────────────────────────

    @Test
    void null_or_zero_gross_returns_zero_without_querying() {
        assertEquals(0, BigDecimal.ZERO
                .compareTo(calc.calculate("MH", "MALE", null, june)));
        assertEquals(0, BigDecimal.ZERO
                .compareTo(calc.calculate("MH", "MALE", BigDecimal.ZERO, june)));
    }

    @Test
    void blank_state_code_returns_zero_without_querying() {
        assertEquals(0, BigDecimal.ZERO
                .compareTo(calc.calculate("", "MALE", new BigDecimal("50000"), june)));
        assertEquals(0, BigDecimal.ZERO
                .compareTo(calc.calculate(null, "MALE", new BigDecimal("50000"), june)));
    }

    // ── Production entry point: org → alphaCode resolution ────────

    @Test
    void calculate_via_orgId_resolves_org_gst_code_to_alpha() {
        UUID orgId = UUID.randomUUID();
        Organisation org = new Organisation();
        org.setStateCode("27"); // Maharashtra
        GstStateCode mh = new GstStateCode();
        mh.setCode("27");
        mh.setAlphaCode("MH");

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(gstStateCodeRepository.findByCodeAndActiveTrue("27"))
                .thenReturn(Optional.of(mh));
        when(ptSlabRepository.findApplicable("MH", "MALE", june)).thenReturn(mhMaleSlabs());

        Employee emp = new Employee();
        emp.setGender("MALE");
        BigDecimal pt = calc.calculate(orgId, emp, new BigDecimal("50000"), june);
        assertEquals(0, new BigDecimal("200.00").compareTo(pt));
    }

    @Test
    void calculate_via_orgId_pads_single_digit_gst_code() {
        UUID orgId = UUID.randomUUID();
        Organisation org = new Organisation();
        org.setStateCode("3"); // user entered "3" instead of "03"
        GstStateCode pb = new GstStateCode();
        pb.setCode("03");
        pb.setAlphaCode("PB");

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(gstStateCodeRepository.findByCodeAndActiveTrue("03"))
                .thenReturn(Optional.of(pb));
        // Punjab has no PT seeded → empty
        when(ptSlabRepository.findApplicable("PB", "MALE", june)).thenReturn(List.of());

        Employee emp = new Employee();
        BigDecimal pt = calc.calculate(orgId, emp, new BigDecimal("50000"), june);
        assertEquals(0, pt.compareTo(BigDecimal.ZERO));
    }

    @Test
    void calculate_via_orgId_returns_zero_when_org_has_no_state() {
        UUID orgId = UUID.randomUUID();
        Organisation org = new Organisation();
        // stateCode left null — freshly-signed-up org with no GST yet
        lenient().when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        BigDecimal pt = calc.calculate(orgId, new Employee(), new BigDecimal("50000"), june);
        assertEquals(0, pt.compareTo(BigDecimal.ZERO));
    }

    // ── helpers ───────────────────────────────────────────────────

    private List<PtSlab> mhMaleSlabs() {
        return List.of(
                slab("MALE", "0", "7500", "0", null),
                slab("MALE", "7500.01", "10000", "175", null),
                slab("MALE", "10000.01", null, "200", "300"));
    }

    private List<PtSlab> mhFemaleSlabs() {
        return List.of(
                slab("FEMALE", "0", "25000", "0", null),
                slab("FEMALE", "25000.01", null, "200", "300"));
    }

    private PtSlab slab(String gender, String from, String to,
                        String monthly, String feb) {
        return PtSlab.builder()
                .id(UUID.randomUUID())
                .stateCode("XX")
                .gender(gender)
                .grossFrom(new BigDecimal(from))
                .grossTo(to == null ? null : new BigDecimal(to))
                .monthlyAmount(new BigDecimal(monthly))
                .febAmount(feb == null ? null : new BigDecimal(feb))
                .effectiveFrom(LocalDate.of(2024, 4, 1))
                .active(true)
                .build();
    }
}
