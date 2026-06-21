package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.entity.PayslipLine;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Generates an EPFO Electronic Challan-cum-Return (ECR) text file from a
 * payroll run. The file is what an employer uploads to the EPFO unified
 * portal to remit monthly PF contributions; the format is fixed by EPFO.
 *
 * <p>Format: one row per employee, fields separated by {@code #~#}, line
 * terminator {@code \r\n}, 11 columns in this exact order:
 * <ol>
 *   <li>UAN (12-digit)</li>
 *   <li>Member Name</li>
 *   <li>Gross Wages</li>
 *   <li>EPF Wages (basic, capped at ₹15,000)</li>
 *   <li>EPS Wages (basic capped; 0 if employee ≥ 58)</li>
 *   <li>EDLI Wages (basic, capped at ₹15,000)</li>
 *   <li>EPF Contribution Remitted (12% of EPF wages, employee share)</li>
 *   <li>EPS Contribution Remitted (8.33% of EPS wages, employer share)</li>
 *   <li>EPF and EPS Difference Remitted (12% of EPF wages − EPS contribution)</li>
 *   <li>NCP Days (non-contributory period — LOP days)</li>
 *   <li>Refund of Advances (always 0; advance refunds are out of scope)</li>
 * </ol>
 *
 * <p>Amounts are whole rupees (EPFO spec — no paise). The statutory PF wage
 * cap is ₹15,000/month; we cap the wage fields and recompute the
 * contributions from the capped wages so the ECR is internally consistent
 * even if the payroll service over-deducted (e.g. uncapped basic).
 *
 * <p>Employees without a UAN are skipped (no ECR identifier). Employees with
 * {@code isPfApplicable() == false} are skipped (not part of PF scheme).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PfEcrFileGenerator {

    private static final String SEP = "#~#";
    private static final String EOL = "\r\n";
    /** Statutory PF wage cap per EPFO Act, current as of FY 2025-26. */
    private static final BigDecimal PF_WAGE_CAP = new BigDecimal("15000");
    /** EPS contribution rate (8.33% of EPS wages). */
    private static final BigDecimal EPS_RATE = new BigDecimal("0.0833");
    /** PF employee/employer rate (12% of PF wages each). */
    private static final BigDecimal PF_RATE = new BigDecimal("0.12");
    /** EPS membership ceases at this age. */
    private static final int EPS_AGE_CEILING = 58;

    private final PayrollRunRepository payrollRunRepository;
    private final PayslipRepository payslipRepository;
    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public String generate(UUID payrollRunId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PayrollRun run = payrollRunRepository.findById(payrollRunId)
                .filter(r -> r.getOrgId().equals(orgId))
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", payrollRunId));

        var payslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, payrollRunId);
        if (payslips.isEmpty()) {
            return ""; // empty file is valid — no employees to remit for
        }

        StringBuilder sb = new StringBuilder();
        for (Payslip ps : payslips) {
            Employee emp = ps.getEmployee();
            if (emp == null) {
                emp = employeeRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(ps.getEmployeeId(), orgId)
                        .orElse(null);
            }
            if (emp == null || !emp.isPfApplicable()) continue;

            String uan = emp.getUan();
            if (uan == null || uan.isBlank()) {
                log.warn("ECR: employee {} has no UAN — skipping", emp.getId());
                continue;
            }

            sb.append(buildLine(emp, ps, run));
            sb.append(EOL);
        }
        return sb.toString();
    }

    public String filename(PayrollRun run) {
        String period = run.getPeriodStart() == null
                ? "" : run.getPeriodStart().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        return "ECR-" + period + ".txt";
    }

    // ── line builder ──────────────────────────────────────────────

    String buildLine(Employee emp, Payslip ps, PayrollRun run) {
        BigDecimal basic = basicFromPayslip(ps);
        BigDecimal grossWages = ps.getGrossPay() == null
                ? BigDecimal.ZERO : ps.getGrossPay();

        // Wages: basic capped at ₹15,000 per EPFO rule. EPS wage is zero once
        // the employee crosses 58 — they only get EPF then.
        BigDecimal epfWages = capWage(basic);
        BigDecimal edliWages = capWage(basic);
        BigDecimal epsWages = isEpsEligible(emp, run) ? capWage(basic) : BigDecimal.ZERO;

        // Contributions — recompute from CAPPED wages so the row is internally
        // consistent (we don't trust uncapped values that may have leaked from
        // the payroll service).
        BigDecimal epfContri = round(epfWages.multiply(PF_RATE));
        BigDecimal epsContri = round(epsWages.multiply(EPS_RATE));
        BigDecimal epfEpsDiff = round(epfWages.multiply(PF_RATE)).subtract(epsContri).max(BigDecimal.ZERO);

        int ncpDays = ps.getLopDays() == null ? 0 : ps.getLopDays().setScale(0, RoundingMode.HALF_UP).intValue();

        return new StringBuilder()
                .append(uan(emp)).append(SEP)
                .append(sanitiseName(emp.getFullName())).append(SEP)
                .append(rupees(grossWages)).append(SEP)
                .append(rupees(epfWages)).append(SEP)
                .append(rupees(epsWages)).append(SEP)
                .append(rupees(edliWages)).append(SEP)
                .append(rupees(epfContri)).append(SEP)
                .append(rupees(epsContri)).append(SEP)
                .append(rupees(epfEpsDiff)).append(SEP)
                .append(ncpDays).append(SEP)
                .append(0)  // Refund of advances
                .toString();
    }

    private static BigDecimal basicFromPayslip(Payslip ps) {
        if (ps.getLines() != null) {
            for (PayslipLine line : ps.getLines()) {
                if (!"EARNING".equals(line.getComponentType())) continue;
                var c = line.getSalaryComponent();
                if (c != null && "BASIC".equalsIgnoreCase(c.getCode())) {
                    return line.getAmount() == null ? BigDecimal.ZERO : line.getAmount();
                }
            }
        }
        // Fallback to gross — defensive, shouldn't happen in practice
        return ps.getGrossPay() == null ? BigDecimal.ZERO : ps.getGrossPay();
    }

    private static BigDecimal capWage(BigDecimal basic) {
        if (basic == null) return BigDecimal.ZERO;
        return basic.compareTo(PF_WAGE_CAP) > 0 ? PF_WAGE_CAP : basic;
    }

    private static boolean isEpsEligible(Employee emp, PayrollRun run) {
        if (emp.getDateOfBirth() == null || run.getPeriodEnd() == null) return true;
        int age = java.time.Period.between(emp.getDateOfBirth(), run.getPeriodEnd()).getYears();
        return age < EPS_AGE_CEILING;
    }

    /** Round to nearest rupee per EPFO ECR spec (no paise in the file). */
    private static BigDecimal round(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v.setScale(0, RoundingMode.HALF_UP);
    }

    /** Render an amount as integer rupees (no decimal, no separators). */
    private static String rupees(BigDecimal v) {
        return round(v).toPlainString();
    }

    /** ECR rejects any field containing `#~#`; strip it just in case. */
    private static String sanitiseName(String name) {
        if (name == null || name.isBlank()) return "";
        return name.replace("#~#", " ").trim();
    }

    private static String uan(Employee emp) {
        String u = emp.getUan() == null ? "" : emp.getUan().trim();
        return u.replaceAll("[^0-9]", "");
    }
}
