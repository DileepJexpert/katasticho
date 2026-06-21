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
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Generates the bank bulk-payment CSV from a payroll run — the file an
 * employer uploads to their corporate banking portal each pay-day to
 * disburse salaries by NACH/IMPS/RTGS.
 *
 * <p>Each bank has slightly different column orders; this service supports
 * the three most-common Indian SMB banks (HDFC, ICICI, SBI) plus a GENERIC
 * fallback that works with most NACH templates.
 *
 * <p>Rules:
 * <ul>
 *   <li>Skips employees with no bank account number (can't be credited).</li>
 *   <li>Skips payslips with non-positive net pay.</li>
 *   <li>Skips employees whose payment mode is explicitly CASH/CHEQUE.</li>
 *   <li>Reference = "SAL-MMYYYY-{employeeCode}" so the reconciliation back to
 *       this payroll run is trivial.</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BankSalaryFileGenerator {

    public enum BankFormat { GENERIC, HDFC, ICICI, SBI }

    private static final String EOL = "\r\n";
    private static final String SEP = ",";

    private final PayrollRunRepository payrollRunRepository;
    private final PayslipRepository payslipRepository;
    private final EmployeeRepository employeeRepository;

    @Transactional(readOnly = true)
    public String generate(UUID payrollRunId, BankFormat format) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PayrollRun run = payrollRunRepository.findById(payrollRunId)
                .filter(r -> r.getOrgId().equals(orgId))
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", payrollRunId));

        if (!"POSTED".equals(run.getStatus()) && !"APPROVED".equals(run.getStatus())) {
            throw new BusinessException(
                    "Bank file can only be generated for APPROVED or POSTED runs; this run is "
                            + run.getStatus(),
                    "PAYROLL_BANK_FILE_NOT_APPROVED", HttpStatus.CONFLICT);
        }

        var payslips = payslipRepository.findByOrgIdAndPayrollRunId(orgId, payrollRunId);
        StringBuilder sb = new StringBuilder();
        sb.append(header(format)).append(EOL);

        String periodTag = run.getPeriodStart() == null
                ? "" : run.getPeriodStart().format(DateTimeFormatter.ofPattern("MMyyyy"));
        int rowsWritten = 0;

        for (Payslip ps : payslips) {
            Employee emp = ps.getEmployee();
            if (emp == null) {
                emp = employeeRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(ps.getEmployeeId(), orgId)
                        .orElse(null);
            }
            if (emp == null) continue;
            if (isCashOrCheque(emp)) continue;
            if (emp.getBankAccountNumber() == null || emp.getBankAccountNumber().isBlank()) {
                log.warn("Bank file: employee {} has no bank account — skipping", emp.getId());
                continue;
            }
            BigDecimal net = ps.getNetPay() == null ? BigDecimal.ZERO : ps.getNetPay();
            if (net.signum() <= 0) continue;

            String reference = "SAL-" + periodTag + "-" + nvl(emp.getEmployeeCode());
            sb.append(line(format, emp, net, reference)).append(EOL);
            rowsWritten++;
        }
        if (rowsWritten == 0) {
            log.warn("Bank file for run {} contains 0 rows — header only", payrollRunId);
        }
        return sb.toString();
    }

    public String filename(PayrollRun run, BankFormat format) {
        String period = run.getPeriodStart() == null
                ? "" : run.getPeriodStart().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        return "Salary-" + format.name() + "-" + period + ".csv";
    }

    // ── per-bank header + row ─────────────────────────────────────

    String header(BankFormat format) {
        return switch (format) {
            // HDFC NetBanking bulk salary upload
            case HDFC ->
                    "Beneficiary Account Number,Beneficiary Name,IFSC Code,Amount,Reference,Email,Mobile";
            // ICICI Corporate iMobile bulk salary
            case ICICI ->
                    "Payment Mode,Beneficiary Code,Beneficiary Name,Beneficiary A/c No,IFSC Code,Amount,Remarks";
            // SBI Cinb Bulk H2H
            case SBI ->
                    "PymtType,DebitAcNo,BeneAcNo,BeneIFSC,BeneName,Amount,Narration,Mobile";
            // Generic NACH-style
            case GENERIC ->
                    "Sr.,Employee Code,Beneficiary Name,Account Number,IFSC,Amount,Mode,Reference";
        };
    }

    String line(BankFormat format, Employee emp, BigDecimal net, String reference) {
        String acct = csv(nvl(emp.getBankAccountNumber()));
        String ifsc = csv(nvl(emp.getBankIfsc()).toUpperCase());
        String name = csv(nvl(emp.getFullName()));
        String amount = net.setScale(2, RoundingMode.HALF_UP).toPlainString();
        String code = csv(nvl(emp.getEmployeeCode()));
        String email = csv(nvl(emp.getEmail()));
        String phone = csv(nvl(emp.getPhone()));
        String ref = csv(reference);

        return switch (format) {
            case HDFC ->
                    String.join(SEP, acct, name, ifsc, amount, ref, email, phone);
            case ICICI ->
                    // Mode "I" = IFT (intra-bank) / "N" = NEFT — bank derives from IFSC; we use "N" as default
                    String.join(SEP, "N", code, name, acct, ifsc, amount, ref);
            case SBI ->
                    // PymtType blank = bank picks NEFT/RTGS by amount; DebitAcNo blank = portal uses session
                    String.join(SEP, "", "", acct, ifsc, name, amount, ref, phone);
            case GENERIC ->
                    String.join(SEP,
                            code, code, name, acct, ifsc, amount,
                            isCashOrCheque(emp) ? "CASH" : "BANK", ref);
        };
    }

    // ── helpers ──────────────────────────────────────────────────

    private static boolean isCashOrCheque(Employee emp) {
        String mode = emp.getPaymentMode();
        if (mode == null) return false;
        String m = mode.trim().toUpperCase();
        return "CASH".equals(m) || "CHEQUE".equals(m);
    }

    /** CSV-escape commas, quotes, newlines. */
    private static String csv(String s) {
        if (s == null) return "";
        if (s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")) {
            return "\"" + s.replace("\"", "\"\"") + "\"";
        }
        return s;
    }

    private static String nvl(String s) { return s == null ? "" : s; }
}
