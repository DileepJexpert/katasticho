package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.EmployeeTaxDeclarationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Manages per-employee, per-FY tax declarations (Form 12BB).
 *
 * <p>Statutory caps (FY 2025-26) baked into {@link #effectiveSection80Deduction}
 * so the salary-TDS calculator (A6) and Form 16 (A7) can call this directly
 * without re-implementing the cap logic.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TaxDeclarationService {

    /** Statutory cap, ₹1,50,000 — Sec 80C. */
    static final BigDecimal CAP_80C = new BigDecimal("150000");
    /** Statutory cap, ₹50,000 — Sec 80CCD(1B) over and above 80C. */
    static final BigDecimal CAP_80CCD1B = new BigDecimal("50000");
    /** Statutory cap, ₹25,000 — Sec 80D self+family (non-senior). */
    static final BigDecimal CAP_80D_SELF = new BigDecimal("25000");
    /** Statutory cap, ₹25,000 — Sec 80D parents (non-senior). */
    static final BigDecimal CAP_80D_PARENTS = new BigDecimal("25000");
    /** Statutory cap, ₹10,000 — Sec 80TTA savings interest. */
    static final BigDecimal CAP_80TTA = new BigDecimal("10000");
    /** Statutory cap, ₹50,000 — Sec 80TTB senior interest. */
    static final BigDecimal CAP_80TTB = new BigDecimal("50000");
    /** Statutory cap, ₹2,00,000 — Sec 24(b) home loan interest, self-occupied. */
    static final BigDecimal CAP_HOMELOAN_INTEREST = new BigDecimal("200000");

    private final EmployeeTaxDeclarationRepository repository;
    private final EmployeeRepository employeeRepository;

    // ── CRUD ──────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Optional<EmployeeTaxDeclaration> findForEmployee(UUID employeeId, String fiscalYear) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByOrgIdAndEmployeeIdAndFiscalYearAndIsDeletedFalse(
                orgId, employeeId, normaliseFy(fiscalYear));
    }

    @Transactional(readOnly = true)
    public EmployeeTaxDeclaration get(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("TaxDeclaration", id));
    }

    @Transactional(readOnly = true)
    public List<EmployeeTaxDeclaration> listForFy(String fiscalYear) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByCreatedAtDesc(
                orgId, normaliseFy(fiscalYear));
    }

    /** Create-or-update the declaration. DRAFT or SUBMITTED rows can be edited; VERIFIED is locked. */
    @Transactional
    public EmployeeTaxDeclaration upsert(UUID employeeId, String fiscalYear,
                                         EmployeeTaxDeclaration patch) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        String fy = normaliseFy(fiscalYear);

        validateRegime(patch.getTaxRegime());

        EmployeeTaxDeclaration existing = repository
                .findByOrgIdAndEmployeeIdAndFiscalYearAndIsDeletedFalse(orgId, employeeId, fy)
                .orElse(null);

        if (existing == null) {
            patch.setOrgId(orgId);
            patch.setEmployeeId(employeeId);
            patch.setFiscalYear(fy);
            if (patch.getStatus() == null || patch.getStatus().isBlank()) patch.setStatus("DRAFT");
            patch.setCreatedBy(userId);
            patch.setUpdatedBy(userId);
            return repository.save(patch);
        }
        if ("VERIFIED".equals(existing.getStatus())) {
            throw new BusinessException(
                    "Declaration is verified — payroll has locked it. Ask payroll to unlock before editing.",
                    "TAX_DECL_VERIFIED_LOCKED", HttpStatus.CONFLICT);
        }
        applyPatch(existing, patch);
        existing.setUpdatedBy(userId);
        return repository.save(existing);
    }

    @Transactional
    public EmployeeTaxDeclaration submit(UUID id) {
        EmployeeTaxDeclaration d = get(id);
        if (!"DRAFT".equals(d.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT declarations can be submitted",
                    "TAX_DECL_NOT_DRAFT", HttpStatus.CONFLICT);
        }
        d.setStatus("SUBMITTED");
        d.setSubmittedAt(Instant.now());
        return repository.save(d);
    }

    @Transactional
    public EmployeeTaxDeclaration verify(UUID id) {
        EmployeeTaxDeclaration d = get(id);
        if (!"SUBMITTED".equals(d.getStatus())) {
            throw new BusinessException(
                    "Only SUBMITTED declarations can be verified",
                    "TAX_DECL_NOT_SUBMITTED", HttpStatus.CONFLICT);
        }
        d.setStatus("VERIFIED");
        d.setVerifiedAt(Instant.now());
        d.setVerifiedBy(TenantContext.getCurrentUserId());
        return repository.save(d);
    }

    /** Soft-delete — only DRAFT rows. */
    @Transactional
    public void delete(UUID id) {
        EmployeeTaxDeclaration d = get(id);
        if (!"DRAFT".equals(d.getStatus())) {
            throw new BusinessException(
                    "Only DRAFT declarations can be deleted",
                    "TAX_DECL_NOT_DRAFT", HttpStatus.CONFLICT);
        }
        d.setDeleted(true);
        repository.save(d);
    }

    // ── Computation helpers ──────────────────────────────────────

    /**
     * Total Section 80 + Sec 24(b) deduction with statutory caps applied
     * per line. Returns ZERO for NEW-regime employees (they forfeit these
     * deductions) and for declarations that are still DRAFT (not finalised).
     *
     * <p>Caller (salary-TDS calc in A6) gets a clean number to subtract from
     * gross-taxable-income.
     */
    @Transactional(readOnly = true)
    public BigDecimal effectiveSection80Deduction(EmployeeTaxDeclaration d) {
        if (d == null) return BigDecimal.ZERO;
        if (!"OLD".equals(d.getTaxRegime())) return BigDecimal.ZERO;
        if ("DRAFT".equals(d.getStatus())) return BigDecimal.ZERO;

        BigDecimal total = BigDecimal.ZERO;
        total = total.add(min(d.getDeduction80c(), CAP_80C));
        total = total.add(min(d.getDeduction80ccd1b(), CAP_80CCD1B));
        total = total.add(min(d.getDeduction80dSelf(), CAP_80D_SELF));
        total = total.add(min(d.getDeduction80dParents(), CAP_80D_PARENTS));
        total = total.add(nonNull(d.getDeduction80e()));     // no cap
        total = total.add(nonNull(d.getDeduction80g()));     // cap is cause-specific; trust declaration
        total = total.add(min(d.getDeduction80tta(), CAP_80TTA));
        total = total.add(min(d.getDeduction80ttb(), CAP_80TTB));
        total = total.add(min(d.getHomeLoanInterest(), CAP_HOMELOAN_INTEREST));
        return total;
    }

    /**
     * HRA exemption (Sec 10(13A)) — least of three: (i) actual HRA, (ii) rent
     * paid minus 10% of basic, (iii) 50% basic (metro) or 40% (non-metro).
     *
     * <p>Caller supplies actual HRA + basic for the period; we apply the
     * least-of-three calc per the standard rule.
     */
    public BigDecimal hraExemption(EmployeeTaxDeclaration d,
                                   BigDecimal hraReceived,
                                   BigDecimal basic) {
        if (d == null || !"OLD".equals(d.getTaxRegime())) return BigDecimal.ZERO;
        if ("DRAFT".equals(d.getStatus())) return BigDecimal.ZERO;
        BigDecimal rent = nonNull(d.getHraRentPaid());
        if (rent.signum() == 0) return BigDecimal.ZERO;

        BigDecimal hra = nonNull(hraReceived);
        BigDecimal b = nonNull(basic);

        BigDecimal cityPct = d.isHraMetroCity() ? new BigDecimal("0.50") : new BigDecimal("0.40");
        BigDecimal rentMinus10Basic = rent.subtract(b.multiply(new BigDecimal("0.10"))).max(BigDecimal.ZERO);
        BigDecimal cityFraction = b.multiply(cityPct);

        return hra.min(rentMinus10Basic).min(cityFraction);
    }

    // ── helpers ───────────────────────────────────────────────────

    private static void validateRegime(String regime) {
        if (regime == null || (!"OLD".equals(regime) && !"NEW".equals(regime))) {
            throw new BusinessException(
                    "tax_regime must be OLD or NEW", "TAX_DECL_INVALID_REGIME",
                    HttpStatus.BAD_REQUEST);
        }
    }

    /** Accept "2026-27", "2026-2027", "FY 2026-27" — return canonical "2026-27". */
    static String normaliseFy(String fy) {
        if (fy == null) throw new BusinessException(
                "fiscal_year is required", "TAX_DECL_FY_REQUIRED", HttpStatus.BAD_REQUEST);
        String s = fy.trim().toUpperCase().replace("FY", "").trim();
        s = s.replace(" ", "");
        // Accept "2026-2027" → "2026-27"
        if (s.matches("\\d{4}-\\d{4}")) {
            int dash = s.indexOf('-');
            s = s.substring(0, dash + 1) + s.substring(dash + 3); // drop century from year2
        }
        if (!s.matches("\\d{4}-\\d{2}")) {
            throw new BusinessException(
                    "fiscal_year must look like 2026-27", "TAX_DECL_FY_FORMAT",
                    HttpStatus.BAD_REQUEST);
        }
        return s;
    }

    private static BigDecimal min(BigDecimal v, BigDecimal cap) {
        BigDecimal x = nonNull(v);
        return x.compareTo(cap) > 0 ? cap : x;
    }

    private static BigDecimal nonNull(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    /** Copy editable fields from patch onto existing — preserves audit + lifecycle. */
    private void applyPatch(EmployeeTaxDeclaration target, EmployeeTaxDeclaration src) {
        if (src.getTaxRegime() != null) target.setTaxRegime(src.getTaxRegime());
        target.setHraRentPaid(src.getHraRentPaid());
        target.setHraMetroCity(src.isHraMetroCity());
        target.setLandlordPan(src.getLandlordPan());
        target.setDeduction80c(src.getDeduction80c());
        target.setDeduction80ccd1b(src.getDeduction80ccd1b());
        target.setDeduction80dSelf(src.getDeduction80dSelf());
        target.setDeduction80dParents(src.getDeduction80dParents());
        target.setDeduction80e(src.getDeduction80e());
        target.setDeduction80g(src.getDeduction80g());
        target.setDeduction80tta(src.getDeduction80tta());
        target.setDeduction80ttb(src.getDeduction80ttb());
        target.setHomeLoanInterest(src.getHomeLoanInterest());
        target.setLtaClaim(src.getLtaClaim());
        target.setOtherIncome(src.getOtherIncome());
        target.setNotes(src.getNotes());
    }
}
