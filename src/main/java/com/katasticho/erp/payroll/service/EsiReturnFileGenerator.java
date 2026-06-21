package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
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
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/**
 * Generates the ESIC monthly contribution CSV from a payroll run — the file
 * an employer uploads to the ESIC portal each month for the Employees' State
 * Insurance return.
 *
 * <p>Format per ESIC portal spec (semicolon-delimited so commas in employee
 * names don't break it; CRLF line terminator). Columns:
 * <ol>
 *   <li>IP Number (10-digit Insurance Person number)</li>
 *   <li>IP Name</li>
 *   <li>No. of Days (working days actually paid for in the month)</li>
 *   <li>Total Monthly Wages (₹, whole rupees)</li>
 *   <li>Reason Code (for zero workings; we leave 0)</li>
 *   <li>Last Working Day (DD/MM/YYYY) — only when employee left this month</li>
 * </ol>
 *
 * <p>Rules:
 * <ul>
 *   <li>ESI applies only when monthly gross ≤ ₹21,000 (statutory ceiling).
 *       Employees above the ceiling are skipped UNLESS they were below at
 *       the start of the half-yearly contribution period (Apr-Sep or
 *       Oct-Mar); we conservatively report them too if they have an ESI
 *       number — the portal will validate. {@link #INCLUDE_ABOVE_CEILING}
 *       can be flipped if a payroll consultant disagrees.</li>
 *   <li>Employees without an ESI number are skipped (no portal identifier).</li>
 *   <li>Employees marked {@code isEsiApplicable=false} are skipped.</li>
 *   <li>Days paid = month total days − LOP days, never negative.</li>
 *   <li>Date of exit triggers the last-working-day column.</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EsiReturnFileGenerator {

    private static final String SEP = ";";
    private static final String EOL = "\r\n";
    private static final BigDecimal ESI_WAGE_CEILING = new BigDecimal("21000");
    private static final boolean INCLUDE_ABOVE_CEILING = true;
    private static final DateTimeFormatter DDMMYYYY = DateTimeFormatter.ofPattern("dd/MM/yyyy");

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
        StringBuilder sb = new StringBuilder();
        sb.append("IP Number;IP Name;No of Days;Total Monthly Wages;Reason Code;Last Working Day").append(EOL);

        for (Payslip ps : payslips) {
            Employee emp = ps.getEmployee();
            if (emp == null) {
                emp = employeeRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(ps.getEmployeeId(), orgId)
                        .orElse(null);
            }
            if (emp == null || !emp.isEsiApplicable()) continue;

            String ip = emp.getEsiNumber();
            if (ip == null || ip.isBlank()) {
                log.warn("ESI: employee {} has no ESI number — skipping", emp.getId());
                continue;
            }

            BigDecimal gross = ps.getGrossPay() == null ? BigDecimal.ZERO : ps.getGrossPay();
            if (!INCLUDE_ABOVE_CEILING && gross.compareTo(ESI_WAGE_CEILING) > 0) continue;

            sb.append(buildLine(emp, ps, run, gross)).append(EOL);
        }
        return sb.toString();
    }

    public String filename(PayrollRun run) {
        String period = run.getPeriodStart() == null
                ? "" : run.getPeriodStart().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        return "ESI-Return-" + period + ".csv";
    }

    String buildLine(Employee emp, Payslip ps, PayrollRun run, BigDecimal gross) {
        int monthDays = (run.getPeriodStart() != null && run.getPeriodEnd() != null)
                ? (int) (ChronoUnit.DAYS.between(run.getPeriodStart(), run.getPeriodEnd()) + 1)
                : 30;
        int lop = ps.getLopDays() == null ? 0 : ps.getLopDays().setScale(0, RoundingMode.HALF_UP).intValue();
        int daysPaid = Math.max(0, monthDays - lop);

        String lastWorkingDay = "";
        if (emp.getDateOfExit() != null && run.getPeriodStart() != null
                && run.getPeriodEnd() != null
                && !emp.getDateOfExit().isBefore(run.getPeriodStart())
                && !emp.getDateOfExit().isAfter(run.getPeriodEnd())) {
            lastWorkingDay = emp.getDateOfExit().format(DDMMYYYY);
        }

        return new StringBuilder()
                .append(sanitise(emp.getEsiNumber()).replaceAll("[^0-9]", "")).append(SEP)
                .append(sanitise(emp.getFullName())).append(SEP)
                .append(daysPaid).append(SEP)
                .append(gross.setScale(0, RoundingMode.HALF_UP)).append(SEP)
                .append(0).append(SEP) // Reason code
                .append(lastWorkingDay)
                .toString();
    }

    /** Strip the field separator from user-supplied strings (defensive). */
    private static String sanitise(String s) {
        if (s == null) return "";
        return s.replace(SEP, " ").trim();
    }
}
