package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.EmployeeTaxDeclarationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TaxDeclarationServiceTest {

    @Mock private EmployeeTaxDeclarationRepository repo;
    @Mock private EmployeeRepository employeeRepo;

    private TaxDeclarationService service;
    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID employeeId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new TaxDeclarationService(repo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    // ── FY normalisation ──────────────────────────────────────────

    @Test
    void normalises_fy_variations_to_canonical_2026_27_form() {
        assertEquals("2026-27", TaxDeclarationService.normaliseFy("2026-27"));
        assertEquals("2026-27", TaxDeclarationService.normaliseFy("2026-2027"));
        assertEquals("2026-27", TaxDeclarationService.normaliseFy("FY 2026-27"));
        assertEquals("2026-27", TaxDeclarationService.normaliseFy(" fy 2026-2027 "));
    }

    @Test
    void rejects_malformed_fiscal_year() {
        assertThrows(BusinessException.class,
                () -> TaxDeclarationService.normaliseFy("not an fy"));
        assertThrows(BusinessException.class,
                () -> TaxDeclarationService.normaliseFy("2026"));
    }

    // ── upsert lifecycle ──────────────────────────────────────────

    @Test
    void upsert_creates_new_when_none_exists() {
        when(repo.findByOrgIdAndEmployeeIdAndFiscalYearAndIsDeletedFalse(
                orgId, employeeId, "2026-27")).thenReturn(Optional.empty());
        when(repo.save(any())).thenAnswer(i -> {
            EmployeeTaxDeclaration d = i.getArgument(0);
            d.setId(UUID.randomUUID());
            return d;
        });

        EmployeeTaxDeclaration patch = new EmployeeTaxDeclaration();
        patch.setTaxRegime("NEW");
        var saved = service.upsert(employeeId, "2026-27", patch);

        assertEquals("NEW", saved.getTaxRegime());
        assertEquals(employeeId, saved.getEmployeeId());
        assertEquals("2026-27", saved.getFiscalYear());
        assertEquals("DRAFT", saved.getStatus());
    }

    @Test
    void upsert_blocks_edit_of_verified_declaration() {
        EmployeeTaxDeclaration existing = base("OLD", "VERIFIED");
        when(repo.findByOrgIdAndEmployeeIdAndFiscalYearAndIsDeletedFalse(
                orgId, employeeId, "2026-27")).thenReturn(Optional.of(existing));

        EmployeeTaxDeclaration patch = new EmployeeTaxDeclaration();
        patch.setTaxRegime("NEW");
        var ex = assertThrows(BusinessException.class,
                () -> service.upsert(employeeId, "2026-27", patch));
        assertEquals("TAX_DECL_VERIFIED_LOCKED", ex.getErrorCode());
    }

    @Test
    void upsert_rejects_bad_regime() {
        EmployeeTaxDeclaration patch = new EmployeeTaxDeclaration();
        patch.setTaxRegime("HYBRID");
        var ex = assertThrows(BusinessException.class,
                () -> service.upsert(employeeId, "2026-27", patch));
        assertEquals("TAX_DECL_INVALID_REGIME", ex.getErrorCode());
    }

    @Test
    void submit_blocks_non_draft() {
        EmployeeTaxDeclaration existing = base("OLD", "SUBMITTED");
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(existing.getId(), orgId))
                .thenReturn(Optional.of(existing));
        var ex = assertThrows(BusinessException.class, () -> service.submit(existing.getId()));
        assertEquals("TAX_DECL_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void submit_stamps_submittedAt_and_moves_status() {
        EmployeeTaxDeclaration existing = base("OLD", "DRAFT");
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(existing.getId(), orgId))
                .thenReturn(Optional.of(existing));
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        var submitted = service.submit(existing.getId());
        assertEquals("SUBMITTED", submitted.getStatus());
        assertNotNull(submitted.getSubmittedAt());
    }

    @Test
    void verify_blocks_non_submitted() {
        EmployeeTaxDeclaration existing = base("OLD", "DRAFT");
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(existing.getId(), orgId))
                .thenReturn(Optional.of(existing));
        var ex = assertThrows(BusinessException.class, () -> service.verify(existing.getId()));
        assertEquals("TAX_DECL_NOT_SUBMITTED", ex.getErrorCode());
    }

    // ── Section 80 caps + regime gating ───────────────────────────

    @Test
    void section80_returns_zero_for_new_regime_employee() {
        EmployeeTaxDeclaration d = base("NEW", "SUBMITTED");
        d.setDeduction80c(new BigDecimal("150000"));
        d.setHomeLoanInterest(new BigDecimal("200000"));
        assertEquals(0, BigDecimal.ZERO.compareTo(service.effectiveSection80Deduction(d)));
    }

    @Test
    void section80_returns_zero_for_draft_declaration_even_in_old_regime() {
        EmployeeTaxDeclaration d = base("OLD", "DRAFT");
        d.setDeduction80c(new BigDecimal("150000"));
        assertEquals(0, BigDecimal.ZERO.compareTo(service.effectiveSection80Deduction(d)));
    }

    @Test
    void section80_caps_each_line_at_its_statutory_limit() {
        EmployeeTaxDeclaration d = base("OLD", "SUBMITTED");
        d.setDeduction80c(new BigDecimal("250000"));        // capped at 150000
        d.setDeduction80ccd1b(new BigDecimal("60000"));     // capped at 50000
        d.setDeduction80dSelf(new BigDecimal("30000"));     // capped at 25000
        d.setDeduction80dParents(new BigDecimal("30000"));  // capped at 25000
        d.setDeduction80tta(new BigDecimal("15000"));       // capped at 10000
        d.setHomeLoanInterest(new BigDecimal("250000"));    // capped at 200000

        BigDecimal expected = new BigDecimal("150000")
                .add(new BigDecimal("50000"))
                .add(new BigDecimal("25000"))
                .add(new BigDecimal("25000"))
                .add(new BigDecimal("10000"))
                .add(new BigDecimal("200000"));

        assertEquals(0, expected.compareTo(service.effectiveSection80Deduction(d)));
    }

    @Test
    void section80_includes_uncapped_lines_at_face_value() {
        EmployeeTaxDeclaration d = base("OLD", "SUBMITTED");
        d.setDeduction80e(new BigDecimal("75000"));
        d.setDeduction80g(new BigDecimal("12000"));

        BigDecimal expected = new BigDecimal("87000");
        assertEquals(0, expected.compareTo(service.effectiveSection80Deduction(d)));
    }

    // ── HRA exemption (least of three) ────────────────────────────

    @Test
    void hra_exemption_picks_least_of_three_metro_case() {
        EmployeeTaxDeclaration d = base("OLD", "SUBMITTED");
        d.setHraRentPaid(new BigDecimal("240000")); // 20k/month rent
        d.setHraMetroCity(true);

        BigDecimal hraReceived = new BigDecimal("180000"); // 15k/month
        BigDecimal basic = new BigDecimal("360000");       // 30k/month basic
        // 50% basic (metro) = 180000
        // rent - 10% basic = 240000 - 36000 = 204000
        // HRA received = 180000
        // Least = 180000
        assertEquals(0, new BigDecimal("180000")
                .compareTo(service.hraExemption(d, hraReceived, basic)));
    }

    @Test
    void hra_exemption_zero_for_new_regime() {
        EmployeeTaxDeclaration d = base("NEW", "SUBMITTED");
        d.setHraRentPaid(new BigDecimal("240000"));
        assertEquals(0, BigDecimal.ZERO.compareTo(
                service.hraExemption(d, new BigDecimal("180000"), new BigDecimal("360000"))));
    }

    @Test
    void hra_exemption_zero_when_no_rent_paid_declared() {
        EmployeeTaxDeclaration d = base("OLD", "SUBMITTED");
        d.setHraRentPaid(BigDecimal.ZERO);
        assertEquals(0, BigDecimal.ZERO.compareTo(
                service.hraExemption(d, new BigDecimal("180000"), new BigDecimal("360000"))));
    }

    @Test
    void hra_exemption_rent_minus_10_basic_caps_high_rent_low_basic() {
        EmployeeTaxDeclaration d = base("OLD", "SUBMITTED");
        d.setHraRentPaid(new BigDecimal("600000"));
        d.setHraMetroCity(false);

        BigDecimal hraReceived = new BigDecimal("100000");
        BigDecimal basic = new BigDecimal("200000");
        // 40% basic (non-metro) = 80000
        // rent - 10% basic = 600000 - 20000 = 580000
        // HRA received = 100000
        // Least = 80000
        assertEquals(0, new BigDecimal("80000")
                .compareTo(service.hraExemption(d, hraReceived, basic)));
    }

    // ── helpers ───────────────────────────────────────────────────

    private EmployeeTaxDeclaration base(String regime, String status) {
        EmployeeTaxDeclaration d = new EmployeeTaxDeclaration();
        d.setId(UUID.randomUUID());
        d.setOrgId(orgId);
        d.setEmployeeId(employeeId);
        d.setFiscalYear("2026-27");
        d.setTaxRegime(regime);
        d.setStatus(status);
        return d;
    }
}
