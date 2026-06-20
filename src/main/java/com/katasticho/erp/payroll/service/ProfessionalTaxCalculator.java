package com.katasticho.erp.payroll.service;

import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.repository.GstStateCodeRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PtSlab;
import com.katasticho.erp.payroll.repository.PtSlabRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * State-wise Professional Tax (PT) calculator. Replaces the legacy flat
 * ₹200/month deduction that was wrong everywhere outside Maharashtra and
 * outright illegal in non-PT states.
 *
 * <p>PT is a state-level tax registered to the employer's establishment, so
 * the relevant state is the <b>organisation's</b> state (per the GST
 * registration), not the employee's residence — an employer in Maharashtra
 * deducts MH PT for all its employees regardless of where they live.
 *
 * <p>Resolution chain:
 * <ol>
 *   <li>{@code organisation.stateCode} (2-digit GST code, e.g. "27") →
 *       {@code GstStateCode.alphaCode} (e.g. "MH") → {@link PtSlab} rows.</li>
 *   <li>If no slabs exist for the state → ₹0 (correct for non-PT states).</li>
 *   <li>If no slab matches the monthly gross → ₹0 (employee is below
 *       the nil bracket).</li>
 *   <li>Pick {@code febAmount} for February when set (MH/OR/MP top up to
 *       hit the ₹2,500 annual cap); else {@code monthlyAmount}.</li>
 * </ol>
 *
 * <p>Gender handling: Maharashtra is the only state with gender-specific
 * slabs. For OTHER / PREFER_NOT_TO_SAY / null the calculator picks the MALE
 * bracket — the more conservative bracket (MH male threshold is ₹7,500 vs
 * female ₹25,000). Employees can claim a refund on annual filing if their
 * actual category warranted less.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProfessionalTaxCalculator {

    private final PtSlabRepository ptSlabRepository;
    private final GstStateCodeRepository gstStateCodeRepository;
    private final OrganisationRepository organisationRepository;

    /** Convenience overload used by tests; production path goes through {@link #calculate(UUID, Employee, BigDecimal, LocalDate)}. */
    public BigDecimal calculate(String alphaCode, String gender,
                                BigDecimal monthlyGross, LocalDate periodEnd) {
        if (alphaCode == null || alphaCode.isBlank()) return BigDecimal.ZERO;
        if (monthlyGross == null || monthlyGross.signum() <= 0) return BigDecimal.ZERO;

        String normalisedGender = normaliseGender(gender);
        List<PtSlab> slabs = ptSlabRepository.findApplicable(
                alphaCode.toUpperCase().trim(), normalisedGender, periodEnd);

        if (slabs.isEmpty()) return BigDecimal.ZERO; // non-PT state

        PtSlab matched = null;
        for (PtSlab s : slabs) {
            if (monthlyGross.compareTo(s.getGrossFrom()) < 0) continue;
            if (s.getGrossTo() != null && monthlyGross.compareTo(s.getGrossTo()) > 0) continue;
            matched = s;
            break;
        }
        if (matched == null) return BigDecimal.ZERO;

        boolean isFebruary = periodEnd != null && periodEnd.getMonthValue() == 2;
        BigDecimal amount = isFebruary && matched.getFebAmount() != null
                ? matched.getFebAmount()
                : matched.getMonthlyAmount();
        return amount == null ? BigDecimal.ZERO : amount;
    }

    /** Production entry point — resolves the org's state from its GST code, then delegates. */
    public BigDecimal calculate(UUID orgId, Employee employee,
                                BigDecimal monthlyGross, LocalDate periodEnd) {
        String alphaCode = resolveOrgAlphaCode(orgId);
        if (alphaCode == null) {
            // Org has no GST state on file → can't pick a slab. Log once and
            // return ZERO; legacy default of ₹200 was wrong in every state.
            log.debug("PT: org {} has no resolvable state — deducting ZERO", orgId);
            return BigDecimal.ZERO;
        }
        return calculate(alphaCode, employee == null ? null : employee.getGender(),
                monthlyGross, periodEnd);
    }

    /** Translate org's 2-digit GST code (e.g. "27") to alphaCode ("MH"). */
    String resolveOrgAlphaCode(UUID orgId) {
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        if (org == null || org.getStateCode() == null || org.getStateCode().isBlank()) {
            return null;
        }
        // org.stateCode is stored as the GST numeric code; pad to 2 digits to
        // tolerate "7" vs "07".
        String gstCode = org.getStateCode().trim();
        if (gstCode.length() == 1) gstCode = "0" + gstCode;
        GstStateCode sc = gstStateCodeRepository
                .findByCodeAndActiveTrue(gstCode).orElse(null);
        return sc == null ? null : sc.getAlphaCode();
    }

    private static String normaliseGender(String gender) {
        if (gender == null) return "MALE";
        String g = gender.toUpperCase().trim();
        return ("MALE".equals(g) || "FEMALE".equals(g)) ? g : "MALE";
    }
}
