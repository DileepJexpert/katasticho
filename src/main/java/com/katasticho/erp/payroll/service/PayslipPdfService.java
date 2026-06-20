package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.common.util.AmountToWordsConverter;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.entity.PayslipLine;
import com.katasticho.erp.payroll.entity.SalaryComponent;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

/**
 * Renders a statutorily-compliant Indian pay slip PDF from a Payslip row.
 * Layout follows Payment of Wages Act minimums: employer header, employee
 * identifiers, pay period, earnings + deductions tables, net pay in figures
 * and words, employer contributions (info-only). HTML → PDF via the shared
 * {@link DocumentPdfService} (open-html-to-pdf), matching the BMR / invoice
 * pipelines.
 *
 * <p>Year-to-date (YTD) columns are deliberately left out of this first cut —
 * they need a per-FY aggregation across all prior payslips for the employee
 * and will be added as a follow-up when Form 16 lands.
 */
@Service
@RequiredArgsConstructor
public class PayslipPdfService {

    private static final DateTimeFormatter PERIOD = DateTimeFormatter.ofPattern("MMMM yyyy");
    private static final DateTimeFormatter SHORT_DATE = DateTimeFormatter.ofPattern("dd-MMM-yyyy");

    private final PayslipRepository payslipRepository;
    private final PayrollRunRepository payrollRunRepository;
    private final OrganisationRepository organisationRepository;
    private final DocumentPdfService pdfService;

    @Transactional(readOnly = true)
    public byte[] generatePdf(UUID payslipId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Payslip ps = payslipRepository.findByIdAndOrgId(payslipId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Payslip", payslipId));
        PayrollRun run = payrollRunRepository.findById(ps.getPayrollRunId())
                .orElseThrow(() -> BusinessException.notFound("PayrollRun", ps.getPayrollRunId()));
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        return pdfService.render(buildHtml(org, run, ps, ps.getEmployee(), ps.getLines()));
    }

    public String filename(Payslip ps, PayrollRun run, Employee emp) {
        String name = emp == null || emp.getFullName() == null
                ? "Employee" : emp.getFullName().replaceAll("[\\\\/:*?\"<>|]", " ").trim();
        String period = run.getPeriodStart() == null
                ? "" : "-" + run.getPeriodStart().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        return ("Payslip-" + name + period + ".pdf");
    }

    // ── HTML builder ───────────────────────────────────────────────

    private String buildHtml(Organisation org, PayrollRun run, Payslip ps,
                             Employee emp, List<PayslipLine> lines) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='utf-8'><style>")
                .append(css())
                .append("</style></head><body>");

        header(sb, org, run);
        employeeBlock(sb, emp);

        BigDecimal earningsTotal = sumOf(lines, "EARNING");
        BigDecimal deductionsTotal = sumOf(lines, "DEDUCTION");
        BigDecimal employerContribTotal = sumOf(lines, "CONTRIBUTION");
        BigDecimal netPay = earningsTotal.subtract(deductionsTotal);

        sb.append("<table class='pay'><tr>");

        // Earnings column
        sb.append("<td class='col'>");
        sb.append("<div class='col-title'>Earnings</div>");
        sb.append("<table class='lines'>");
        for (PayslipLine line : lines) {
            if ("EARNING".equals(line.getComponentType())) {
                row(sb, componentName(line), line.getAmount());
            }
        }
        totalRow(sb, "Gross Earnings", earningsTotal);
        sb.append("</table>");
        sb.append("</td>");

        // Deductions column
        sb.append("<td class='col'>");
        sb.append("<div class='col-title'>Deductions</div>");
        sb.append("<table class='lines'>");
        for (PayslipLine line : lines) {
            if ("DEDUCTION".equals(line.getComponentType())) {
                row(sb, componentName(line), line.getAmount());
            }
        }
        totalRow(sb, "Total Deductions", deductionsTotal);
        sb.append("</table>");
        sb.append("</td>");

        sb.append("</tr></table>");

        // Net pay block
        sb.append("<div class='net'>");
        sb.append("<table class='net-table'><tr>");
        sb.append("<td class='net-label'>Net Pay</td>");
        sb.append("<td class='net-amount'>").append(formatRupees(netPay)).append("</td>");
        sb.append("</tr></table>");
        sb.append("<div class='words'>").append(esc(AmountToWordsConverter.convert(netPay)))
                .append("</div>");
        sb.append("</div>");

        // Employer contributions (info-only)
        if (employerContribTotal.signum() > 0) {
            sb.append("<div class='ec'>");
            sb.append("<div class='ec-title'>Employer Contributions (not paid to employee)</div>");
            sb.append("<table class='lines'>");
            for (PayslipLine line : lines) {
                if ("CONTRIBUTION".equals(line.getComponentType())) {
                    row(sb, componentName(line), line.getAmount());
                }
            }
            totalRow(sb, "Total Employer Contributions", employerContribTotal);
            sb.append("</table>");
            sb.append("</div>");
        }

        footer(sb);
        sb.append("</body></html>");
        return sb.toString();
    }

    private void header(StringBuilder sb, Organisation org, PayrollRun run) {
        sb.append("<div class='hdr'>");
        sb.append("<div class='org-name'>").append(esc(org.getName())).append("</div>");
        String addr1 = nullSafe(org.getAddressLine1());
        String addr2 = nullSafe(org.getAddressLine2());
        String cityState = joinNonEmpty(", ", nullSafe(org.getCity()),
                nullSafe(org.getState()), nullSafe(org.getPostalCode()));
        if (!addr1.isEmpty()) sb.append("<div class='org-addr'>").append(esc(addr1)).append("</div>");
        if (!addr2.isEmpty()) sb.append("<div class='org-addr'>").append(esc(addr2)).append("</div>");
        if (!cityState.isEmpty()) sb.append("<div class='org-addr'>").append(esc(cityState)).append("</div>");
        if (org.getGstin() != null && !org.getGstin().isBlank()) {
            sb.append("<div class='org-addr'>GSTIN: ").append(esc(org.getGstin())).append("</div>");
        }
        sb.append("</div>");

        sb.append("<div class='banner'>PAY SLIP for ");
        if (run.getPeriodStart() != null) sb.append(esc(run.getPeriodStart().format(PERIOD)));
        sb.append("</div>");
    }

    private void employeeBlock(StringBuilder sb, Employee emp) {
        if (emp == null) {
            sb.append("<div class='emp-missing'>Employee record not found</div>");
            return;
        }
        sb.append("<table class='emp'>");
        empRow(sb, "Employee Name", emp.getFullName(),
                "Employee Code", emp.getEmployeeCode());
        empRow(sb, "Designation", emp.getDesignation(),
                "Department", emp.getDepartment());
        empRow(sb, "Date of Joining",
                emp.getDateOfJoining() == null ? "" : emp.getDateOfJoining().format(SHORT_DATE),
                "Location", emp.getWorkLocation());
        empRow(sb, "PAN", emp.getPan(),
                "UAN", emp.getUan());
        empRow(sb, "ESI No.", emp.getEsiNumber(),
                "Bank A/c", emp.getBankAccountNumber());
        sb.append("</table>");
    }

    private void empRow(StringBuilder sb, String l1, String v1, String l2, String v2) {
        sb.append("<tr>");
        sb.append("<td class='emp-label'>").append(esc(l1)).append("</td>");
        sb.append("<td class='emp-value'>").append(esc(nullSafe(v1))).append("</td>");
        sb.append("<td class='emp-label'>").append(esc(l2)).append("</td>");
        sb.append("<td class='emp-value'>").append(esc(nullSafe(v2))).append("</td>");
        sb.append("</tr>");
    }

    private void row(StringBuilder sb, String label, BigDecimal amount) {
        sb.append("<tr><td class='lbl'>").append(esc(label)).append("</td>")
          .append("<td class='amt'>").append(formatRupees(amount)).append("</td></tr>");
    }

    private void totalRow(StringBuilder sb, String label, BigDecimal amount) {
        sb.append("<tr class='tot'><td class='lbl'>").append(esc(label)).append("</td>")
          .append("<td class='amt'>").append(formatRupees(amount)).append("</td></tr>");
    }

    private void footer(StringBuilder sb) {
        sb.append("<div class='ftr'>")
          .append("This is a system-generated pay slip; no signature is required. ")
          .append("Generated on ")
          .append(esc(java.time.LocalDate.now().format(SHORT_DATE)))
          .append(".</div>");
    }

    private String componentName(PayslipLine line) {
        SalaryComponent c = line.getSalaryComponent();
        if (c == null) return "(component)";
        return c.getName() != null && !c.getName().isBlank() ? c.getName() : c.getCode();
    }

    private BigDecimal sumOf(List<PayslipLine> lines, String type) {
        BigDecimal total = BigDecimal.ZERO;
        for (PayslipLine line : lines) {
            if (type.equals(line.getComponentType()) && line.getAmount() != null) {
                total = total.add(line.getAmount());
            }
        }
        return total;
    }

    // ── helpers ────────────────────────────────────────────────────

    private static String nullSafe(String s) { return s == null ? "" : s; }

    private static String joinNonEmpty(String sep, String... parts) {
        StringBuilder sb = new StringBuilder();
        for (String p : parts) {
            if (p == null || p.isBlank()) continue;
            if (sb.length() > 0) sb.append(sep);
            sb.append(p);
        }
        return sb.toString();
    }

    /** HTML-escape user-supplied strings to prevent XSS via org name / employee name. */
    private static String esc(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '<': sb.append("&lt;"); break;
                case '>': sb.append("&gt;"); break;
                case '&': sb.append("&amp;"); break;
                case '"': sb.append("&quot;"); break;
                case '\'': sb.append("&#39;"); break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }

    private static String formatRupees(BigDecimal amount) {
        if (amount == null) amount = BigDecimal.ZERO;
        BigDecimal v = amount.setScale(2, RoundingMode.HALF_UP);
        // Indian grouping (lakh/crore): 12,34,567.89
        String[] split = v.toPlainString().split("\\.");
        String intPart = split[0];
        String fracPart = split.length > 1 ? split[1] : "00";
        String sign = "";
        if (intPart.startsWith("-")) { sign = "-"; intPart = intPart.substring(1); }
        StringBuilder out = new StringBuilder();
        int len = intPart.length();
        if (len <= 3) {
            out.append(intPart);
        } else {
            String last3 = intPart.substring(len - 3);
            String rest = intPart.substring(0, len - 3);
            // Split the rest in pairs from the right
            StringBuilder grouped = new StringBuilder();
            int n = rest.length();
            for (int i = n; i > 0; i -= 2) {
                int from = Math.max(0, i - 2);
                if (grouped.length() > 0) grouped.insert(0, ",");
                grouped.insert(0, rest.substring(from, i));
            }
            out.append(grouped).append(",").append(last3);
        }
        return "₹ " + sign + out + "." + fracPart;
    }

    private String css() {
        return "@page{size:A4;margin:18mm 16mm;}"
                + "body{font-family:'Helvetica','Arial',sans-serif;font-size:10px;color:#222;}"
                + ".hdr{text-align:center;margin-bottom:6px;}"
                + ".org-name{font-size:14px;font-weight:700;}"
                + ".org-addr{font-size:9px;color:#444;}"
                + ".banner{background:#1f2937;color:#fff;text-align:center;padding:6px;font-size:12px;font-weight:700;margin:8px 0 10px;letter-spacing:0.5px;}"
                + ".emp{width:100%;border-collapse:collapse;margin-bottom:10px;}"
                + ".emp td{border:1px solid #d1d5db;padding:4px 6px;font-size:10px;}"
                + ".emp-label{background:#f3f4f6;width:18%;font-weight:600;}"
                + ".emp-value{width:32%;}"
                + ".emp-missing{padding:8px;background:#fee2e2;color:#991b1b;}"
                + ".pay{width:100%;border-collapse:collapse;}"
                + ".pay .col{width:50%;vertical-align:top;padding:0 4px;}"
                + ".col-title{background:#374151;color:#fff;padding:4px 6px;font-size:10px;font-weight:700;}"
                + ".lines{width:100%;border-collapse:collapse;border:1px solid #d1d5db;border-top:0;}"
                + ".lines td{padding:3px 6px;font-size:10px;border-bottom:1px solid #e5e7eb;}"
                + ".lines .lbl{text-align:left;}"
                + ".lines .amt{text-align:right;font-family:'Courier New',monospace;}"
                + ".lines tr.tot td{font-weight:700;background:#f3f4f6;border-top:1px solid #9ca3af;border-bottom:0;}"
                + ".net{margin:14px 0 8px;}"
                + ".net-table{width:100%;border-collapse:collapse;}"
                + ".net-label{background:#1f2937;color:#fff;padding:8px;font-weight:700;font-size:12px;width:70%;}"
                + ".net-amount{background:#1f2937;color:#fff;padding:8px;text-align:right;font-family:'Courier New',monospace;font-weight:700;font-size:13px;}"
                + ".words{padding:6px 8px;background:#f9fafb;border:1px solid #e5e7eb;border-top:0;font-style:italic;}"
                + ".ec{margin-top:14px;}"
                + ".ec-title{background:#4b5563;color:#fff;padding:4px 6px;font-size:10px;font-weight:700;}"
                + ".ftr{margin-top:18px;text-align:center;font-size:9px;color:#666;}";
    }
}
