package com.katasticho.erp.payroll.gulf;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * UAE Wages Protection System (WPS) — SIF v2 file generator.
 *
 * <p>The Salary Information File (SIF) is the format every UAE employer must
 * submit through their bank (the "agent bank") for the Central Bank's WPS
 * to release the employees' net pay. One file per payroll run, pipe-delimited,
 * UTF-8, single header (SCR) + one EDR record per employee.
 *
 * <pre>
 *   SCR | EmployerEID | EmployerBankCode | FileDate | FileTime | YYYYMM | Records | TotalSalary | SIF v2.0 | reserved
 *   EDR | EmployerEID | EmployeeRef | EmployeeBankCode | EmployeeIBAN | PeriodStart | PeriodEnd | Days | FixedAmt | VariableAmt | LeaveStart | LeaveEnd
 *   ... one EDR per employee ...
 * </pre>
 *
 * <p>Dates are {@code DDMMYYYY}; time is {@code HHmm}; period dates use the
 * same {@code DDMMYYYY} format. The variable-component column is for
 * commissions/incentives — split off the legacy single-amount only when the
 * payroll engine starts distinguishing them; until then everything posts under
 * the fixed column, which is how every Gulf SMB submits today.
 *
 * <p>Org settings (all under {@code payroll.wps.*}):
 * <ul>
 *   <li>{@code employer_eid} — 13-digit Establishment ID Number (MoHRE),
 *       mandatory.</li>
 *   <li>{@code employer_bank_code} — 3-character bank code of the agent bank
 *       (e.g. {@code EBI} for Emirates NBD), mandatory.</li>
 *   <li>{@code employee_bank_code} — fallback 3-char code when an employee's
 *       record doesn't carry one (single-bank shops). Optional.</li>
 * </ul>
 *
 * <p>Country-gated to AE on the controller — the controller throws
 * FEATURE_NOT_AVAILABLE_IN_COUNTRY on a non-AE org before the file is built.
 * Oman has a comparable WPS but uses a different format (Oman National Wage
 * Protection System) — built in a separate file generator when needed.
 */
@Service
@RequiredArgsConstructor
public class WpsFileService {

    static final String SETTING_EMPLOYER_EID = "payroll.wps.employer_eid";
    static final String SETTING_EMPLOYER_BANK = "payroll.wps.employer_bank_code";
    static final String SETTING_EMPLOYEE_BANK_DEFAULT = "payroll.wps.employee_bank_code";
    static final String SIF_VERSION = "SIF v2.0";

    private static final DateTimeFormatter DDMMYYYY = DateTimeFormatter.ofPattern("ddMMyyyy");
    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HHmm");
    private static final DateTimeFormatter YYYYMM = DateTimeFormatter.ofPattern("yyyyMM");

    private final PayrollRunRepository payrollRunRepository;
    private final PayslipRepository payslipRepository;
    private final EmployeeRepository employeeRepository;
    private final OrgSettingsService orgSettingsService;
    private final Clock clock;

    /** Generated SIF body + metadata for the API response / download. */
    public record WpsFile(String filename, String content, int employeeCount, BigDecimal totalSalary) {
    }

    @Transactional(readOnly = true)
    public WpsFile generate(UUID payrollRunId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PayrollRun run = payrollRunRepository.findById(payrollRunId)
                .filter(r -> orgId.equals(r.getOrgId()))
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", payrollRunId));

        String employerEid = required(orgSettingsService.get(orgId, SETTING_EMPLOYER_EID, ""),
                "WPS employer EID (13 digit MoHRE Establishment ID)",
                SETTING_EMPLOYER_EID);
        String employerBank = required(orgSettingsService.get(orgId, SETTING_EMPLOYER_BANK, ""),
                "WPS employer bank code (3-char agent-bank code)",
                SETTING_EMPLOYER_BANK);
        String defaultEmployeeBank = orgSettingsService.get(orgId, SETTING_EMPLOYEE_BANK_DEFAULT, "");

        List<Payslip> payslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, payrollRunId);
        if (payslips.isEmpty()) {
            throw new BusinessException(
                    "Payroll run has no payslips — cannot generate WPS file",
                    "WPS_RUN_EMPTY", HttpStatus.BAD_REQUEST);
        }

        Map<UUID, Employee> employees = employeesById(orgId, payslips);

        StringBuilder body = new StringBuilder();
        BigDecimal totalSalary = BigDecimal.ZERO;
        int recordCount = 0;
        // Inclusive day count: a Jun 1–Jun 30 run is 30 days, not 29.
        // Using Period.getDays() would have given the days-portion only (0 for
        // a full month) — ChronoUnit.DAYS counts the total span.
        long periodDays = java.time.temporal.ChronoUnit.DAYS.between(
                run.getPeriodStart(), run.getPeriodEnd().plusDays(1));

        for (Payslip p : payslips) {
            Employee e = employees.get(p.getEmployeeId());
            if (e == null) continue;  // soft-deleted between calc + WPS export
            BigDecimal net = nz(p.getNetPay()).setScale(2, RoundingMode.HALF_UP);
            if (net.signum() <= 0) continue;  // skip zero-net payslips (LOP holidays)

            String employeeIban = required(e.getBankAccountNumber(),
                    "IBAN for employee " + e.getFullName(),
                    "employee.bank_account_number");
            String employeeBank = blankToNull(defaultEmployeeBank);
            if (employeeBank == null) {
                employeeBank = required(blankToNull(e.getBankIfsc()),
                        "Bank code for employee " + e.getFullName(),
                        "employee.bank_ifsc");
            }
            String employeeRef = blankToNull(e.getEmployeeCode());
            if (employeeRef == null) {
                employeeRef = blankToNull(e.getEsiNumber()); // fallback for shops re-using esi_number as Labour Card no
            }
            if (employeeRef == null) {
                throw new BusinessException(
                        "Employee " + e.getFullName() + " has no Labour Card / employee code — required for WPS",
                        "WPS_NO_EMPLOYEE_REF", HttpStatus.BAD_REQUEST);
            }

            body.append("EDR|").append(employerEid)
                    .append("|").append(employeeRef)
                    .append("|").append(employeeBank)
                    .append("|").append(employeeIban)
                    .append("|").append(run.getPeriodStart().format(DDMMYYYY))
                    .append("|").append(run.getPeriodEnd().format(DDMMYYYY))
                    .append("|").append(periodDays)
                    .append("|").append(net.toPlainString())  // fixed component (full net for now)
                    .append("|0.00")                          // variable component
                    .append("|||")                            // leave start | leave end | filler
                    .append("\n");

            totalSalary = totalSalary.add(net);
            recordCount++;
        }

        if (recordCount == 0) {
            throw new BusinessException(
                    "No payable employees in this run — every payslip is zero-net",
                    "WPS_NO_PAYABLE", HttpStatus.BAD_REQUEST);
        }

        LocalDateTime now = LocalDateTime.now(clock);
        String header = "SCR|" + employerEid
                + "|" + employerBank
                + "|" + now.toLocalDate().format(DDMMYYYY)
                + "|" + now.toLocalTime().format(HHMM)
                + "|" + run.getPeriodEnd().format(YYYYMM)
                + "|" + String.format("%05d", recordCount)
                + "|" + totalSalary.setScale(2, RoundingMode.HALF_UP).toPlainString()
                + "|" + SIF_VERSION
                + "|\n";

        String filename = "WPS-" + run.getPeriodEnd().format(YYYYMM) + "-"
                + employerEid + ".sif";
        return new WpsFile(filename, header + body, recordCount,
                totalSalary.setScale(2, RoundingMode.HALF_UP));
    }

    private Map<UUID, Employee> employeesById(UUID orgId, List<Payslip> payslips) {
        Map<UUID, Employee> out = new HashMap<>();
        for (Payslip p : payslips) {
            employeeRepository.findById(p.getEmployeeId())
                    .filter(e -> orgId.equals(e.getOrgId()) && !e.isDeleted())
                    .ifPresent(e -> out.put(e.getId(), e));
        }
        return out;
    }

    private static String required(String value, String label, String code) {
        String trimmed = value == null ? null : value.trim();
        if (trimmed == null || trimmed.isEmpty()) {
            throw new BusinessException(
                    "Missing " + label + " — configure org setting '" + code + "'",
                    "WPS_MISSING_" + code.toUpperCase().replace('.', '_'),
                    HttpStatus.BAD_REQUEST);
        }
        return trimmed;
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    /** Exposed for diagnostic / preview UI. */
    public LocalDate today() {
        return LocalDate.now(clock);
    }
}
