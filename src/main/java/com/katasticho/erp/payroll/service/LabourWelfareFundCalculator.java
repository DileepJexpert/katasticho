package com.katasticho.erp.payroll.service;

import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.repository.GstStateCodeRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.LwfRule;
import com.katasticho.erp.payroll.repository.LwfRuleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * State-wise Labour Welfare Fund calculator. Replaces the legacy flat
 * ₹25 employee + ₹75 employer block that was wrong everywhere except
 * Maharashtra and (worse) charged every month instead of half-yearly.
 *
 * <p>Same org→state resolution chain as {@link ProfessionalTaxCalculator}:
 * org's 2-digit GST code → {@code GstStateCode.alphaCode} → {@link LwfRule}.
 *
 * <p>Frequency handling — the killer detail. Most states deduct LWF only in
 * specific months (Maharashtra Jun+Dec, Karnataka Dec, Chhattisgarh Mar+Sep,
 * etc). The calculator checks whether the payslip's period month is in the
 * rule's {@code collectionMonths} set; if not, both employee and employer
 * contributions are ₹0 for that month — preventing the legacy bug of
 * collecting a half-yearly amount every single month.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LabourWelfareFundCalculator {

    /** Employee + employer contribution amounts for one payroll month. */
    public record Contribution(BigDecimal employee, BigDecimal employer) {
        public static final Contribution ZERO = new Contribution(BigDecimal.ZERO, BigDecimal.ZERO);

        public boolean hasAny() {
            return employee.signum() > 0 || employer.signum() > 0;
        }
    }

    private final LwfRuleRepository lwfRuleRepository;
    private final GstStateCodeRepository gstStateCodeRepository;
    private final OrganisationRepository organisationRepository;

    /** Test-friendly overload — calculates directly from an alphaCode. */
    public Contribution calculate(String alphaCode, BigDecimal monthlyGross, LocalDate periodEnd) {
        if (alphaCode == null || alphaCode.isBlank()) return Contribution.ZERO;
        if (periodEnd == null) return Contribution.ZERO;

        List<LwfRule> rules = lwfRuleRepository.findApplicable(
                alphaCode.toUpperCase().trim(), periodEnd);
        if (rules.isEmpty()) return Contribution.ZERO; // non-LWF state

        BigDecimal gross = monthlyGross == null ? BigDecimal.ZERO : monthlyGross;
        LwfRule matched = null;
        for (LwfRule r : rules) {
            if (gross.compareTo(r.getGrossFrom()) < 0) continue;
            if (r.getGrossTo() != null && gross.compareTo(r.getGrossTo()) > 0) continue;
            matched = r;
            break;
        }
        if (matched == null) return Contribution.ZERO;

        // Collection month gate — the most critical detail. A half-yearly
        // ₹25 must NOT be charged every month.
        if (!isCollectionMonth(matched.getCollectionMonths(), periodEnd.getMonthValue())) {
            return Contribution.ZERO;
        }

        return new Contribution(
                matched.getEmployeeAmount() == null ? BigDecimal.ZERO : matched.getEmployeeAmount(),
                matched.getEmployerAmount() == null ? BigDecimal.ZERO : matched.getEmployerAmount());
    }

    /** Production entry point — resolves the org's state, then delegates. */
    public Contribution calculate(UUID orgId, BigDecimal monthlyGross, LocalDate periodEnd) {
        String alphaCode = resolveOrgAlphaCode(orgId);
        if (alphaCode == null) {
            log.debug("LWF: org {} has no resolvable state — returning ZERO", orgId);
            return Contribution.ZERO;
        }
        return calculate(alphaCode, monthlyGross, periodEnd);
    }

    /** Translate org's 2-digit GST code (e.g. "27") to alphaCode ("MH"). */
    String resolveOrgAlphaCode(UUID orgId) {
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        if (org == null || org.getStateCode() == null || org.getStateCode().isBlank()) {
            return null;
        }
        String gstCode = org.getStateCode().trim();
        if (gstCode.length() == 1) gstCode = "0" + gstCode;
        GstStateCode sc = gstStateCodeRepository.findByCodeAndActiveTrue(gstCode).orElse(null);
        return sc == null ? null : sc.getAlphaCode();
    }

    static boolean isCollectionMonth(String collectionMonths, int month) {
        if (collectionMonths == null || collectionMonths.isBlank()) return false;
        Set<Integer> months = new HashSet<>();
        for (String s : Arrays.asList(collectionMonths.split(","))) {
            try {
                months.add(Integer.parseInt(s.trim()));
            } catch (NumberFormatException ignored) { /* skip malformed */ }
        }
        return months.contains(month);
    }
}
