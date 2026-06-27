package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;

/**
 * Renders <b>Form 12BB</b> (Rule 26C, Income-tax Rules 1962) — the statement
 * an employee submits to the employer declaring the claims used to compute
 * salary TDS (Sec 192): HRA, LTA, home-loan interest, and Chapter VI-A
 * deductions. The employer files the signed form with the employee's IT proofs.
 *
 * <p>Source data is the captured {@link EmployeeTaxDeclaration} (created via
 * {@link TaxDeclarationService}); the employee's name/PAN/designation are
 * resolved from the payroll {@link Employee} master.
 *
 * <p>HTML → PDF via the shared {@link DocumentPdfService} (open-html-to-pdf),
 * matching the Form 16 / BMR / payslip pipelines.
 */
@Service
@RequiredArgsConstructor
public class Form12BBPdfService {

    private final TaxDeclarationService taxDeclarationService;
    private final EmployeeRepository employeeRepository;
    private final DocumentPdfService pdfService;

    @Transactional(readOnly = true)
    public byte[] generatePdf(UUID declarationId) {
        EmployeeTaxDeclaration decl = taxDeclarationService.get(declarationId);
        Employee emp = employeeRepository
                .findByIdAndOrgIdAndIsDeletedFalse(decl.getEmployeeId(), decl.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Employee", decl.getEmployeeId()));
        return pdfService.render(buildHtml(decl, emp));
    }

    public String filename(EmployeeTaxDeclaration decl, String employeeName) {
        String name = employeeName == null || employeeName.isBlank()
                ? "Employee" : employeeName.replaceAll("[\\\\/:*?\"<>|]", " ").trim();
        String fy = decl == null || decl.getFiscalYear() == null ? "" : decl.getFiscalYear();
        return "Form12BB-" + name + "-FY" + fy + ".pdf";
    }

    // ── HTML builder ──────────────────────────────────────────────

    String buildHtml(EmployeeTaxDeclaration d, Employee emp) {
        boolean newRegime = "NEW".equalsIgnoreCase(asString(d.getTaxRegime()));
        String fy = asString(d.getFiscalYear());

        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='utf-8'><style>")
          .append(css())
          .append("</style></head><body>");

        sb.append("<div class='banner'>FORM 12BB — Statement of particulars for deduction of tax (Rule 26C)</div>");
        sb.append("<div class='subbanner'>FY ").append(esc(fy))
          .append(" · Assessment Year ").append(esc(assessmentYear(fy)))
          .append(" · Tax Regime: ").append(esc(newRegime ? "NEW (concessional u/s 115BAC)" : "OLD"))
          .append("</div>");

        // Employee header
        sb.append("<table class='hdr'><tr><td class='hdr-cell'>")
          .append("<div class='section-title'>Employee</div>")
          .append("<div class='val'>").append(esc(name(emp))).append("</div>")
          .append("<div class='val small'>Employee Code: ").append(esc(asString(emp.getEmployeeCode()))).append("</div>")
          .append("<div class='val small'>Designation: ").append(esc(asString(emp.getDesignation()))).append("</div>")
          .append("<div class='val small'>PAN: ").append(esc(asString(emp.getPan()))).append("</div>")
          .append("</td></tr></table>");

        if (newRegime) {
            sb.append("<div class='warn'>This declaration is under the NEW tax regime (Sec 115BAC). "
                    + "HRA exemption and Chapter VI-A deductions (other than 80CCD(2)) are not available; "
                    + "the figures below are recorded for the employee's records only.</div>");
        }

        // 1. HRA
        sb.append("<div class='part-title'>1. House Rent Allowance</div>");
        BigDecimal rent = asMoney(d.getHraRentPaid());
        if (rent.signum() > 0) {
            sb.append("<table class='data'><tbody>");
            row(sb, "Rent paid to the landlord", rent);
            sb.append("<tr><td>City type</td><td class='num'>")
              .append(d.isHraMetroCity() ? "Metro (50%)" : "Non-metro (40%)").append("</td></tr>");
            String landlordPan = asString(d.getLandlordPan());
            sb.append("<tr><td>Landlord PAN ")
              .append("<span class='note'>(mandatory if annual rent &gt; ₹1,00,000)</span></td>")
              .append("<td class='num'>")
              .append(landlordPan.isBlank() ? "<span class='miss'>Not provided</span>" : esc(landlordPan))
              .append("</td></tr>");
            sb.append("</tbody></table>");
        } else {
            sb.append("<div class='nil'>Nil declared.</div>");
        }

        // 2. LTA
        sb.append("<div class='part-title'>2. Leave Travel Concession / Assistance</div>");
        BigDecimal lta = asMoney(d.getLtaClaim());
        if (lta.signum() > 0) {
            sb.append("<table class='data'><tbody>");
            row(sb, "Amount of LTA / LTC claimed", lta);
            sb.append("</tbody></table>");
        } else {
            sb.append("<div class='nil'>Nil declared.</div>");
        }

        // 3. Interest on home loan
        sb.append("<div class='part-title'>3. Deduction of interest on borrowing (Sec 24)</div>");
        BigDecimal homeLoan = asMoney(d.getHomeLoanInterest());
        if (homeLoan.signum() > 0) {
            sb.append("<table class='data'><tbody>");
            row(sb, "Interest payable / paid to the lender", homeLoan);
            sb.append("</tbody></table>");
        } else {
            sb.append("<div class='nil'>Nil declared.</div>");
        }

        // 4. Chapter VI-A
        sb.append("<div class='part-title'>4. Deduction under Chapter VI-A</div>");
        sb.append("<table class='data'><thead><tr><th>Section</th><th class='num'>Amount (₹)</th></tr></thead><tbody>");
        BigDecimal chapViaTotal = BigDecimal.ZERO;
        chapViaTotal = chapViaTotal.add(optRow(sb, "80C — LIC / PF / ELSS / tuition / principal", d.getDeduction80c()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80CCD(1B) — NPS (additional ₹50,000)", d.getDeduction80ccd1b()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80D — Medical insurance (self & family)", d.getDeduction80dSelf()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80D — Medical insurance (parents)", d.getDeduction80dParents()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80E — Interest on education loan", d.getDeduction80e()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80G — Donations", d.getDeduction80g()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80TTA — Savings-account interest", d.getDeduction80tta()));
        chapViaTotal = chapViaTotal.add(optRow(sb, "80TTB — Interest income (senior citizen)", d.getDeduction80ttb()));
        if (chapViaTotal.signum() == 0) {
            sb.append("<tr><td colspan='2' class='nil'>Nil declared.</td></tr>");
        } else {
            sb.append("<tr class='tot'><td>Total Chapter VI-A declared</td><td class='num'>")
              .append(formatMoney(chapViaTotal)).append("</td></tr>");
        }
        sb.append("</tbody></table>");

        // Other income
        BigDecimal otherIncome = asMoney(d.getOtherIncome());
        if (otherIncome.signum() > 0) {
            sb.append("<div class='part-title'>5. Other income reported to employer</div>");
            sb.append("<table class='data'><tbody>");
            row(sb, "Income other than salary", otherIncome);
            sb.append("</tbody></table>");
        }

        // Status + verification
        sb.append("<div class='status'>Status: <b>").append(esc(asString(d.getStatus()))).append("</b>");
        if (d.getSubmittedAt() != null) {
            sb.append(" · Submitted: ").append(esc(d.getSubmittedAt().toString()));
        }
        if (d.getVerifiedAt() != null) {
            sb.append(" · Verified: ").append(esc(d.getVerifiedAt().toString()));
        }
        sb.append("</div>");

        if (d.getNotes() != null && !d.getNotes().isBlank()) {
            sb.append("<div class='words'>").append(esc(d.getNotes())).append("</div>");
        }

        sb.append("<div class='verification'>")
          .append("<b>Verification.</b> I, ").append(esc(name(emp)))
          .append(", do hereby certify that the information given above is complete and correct.")
          .append("<div class='sign'>Date: ____________ &nbsp;&nbsp; Place: ____________ "
                  + "&nbsp;&nbsp;&nbsp;&nbsp; Signature of the employee: ____________________</div>")
          .append("</div>");

        sb.append("<div class='footer'>")
          .append("This Form 12BB is system-generated from the employee's captured declaration. ")
          .append("Generated on ").append(esc(java.time.LocalDate.now().toString())).append(".")
          .append("</div>");

        sb.append("</body></html>");
        return sb.toString();
    }

    // ── helpers ──────────────────────────────────────────────────

    private void row(StringBuilder sb, String label, BigDecimal amount) {
        sb.append("<tr><td>").append(esc(label)).append("</td><td class='num'>")
          .append(formatMoney(amount)).append("</td></tr>");
    }

    /** Append a row only when the value is positive; return the value (or zero) for totalling. */
    private BigDecimal optRow(StringBuilder sb, String label, BigDecimal raw) {
        BigDecimal v = asMoney(raw);
        if (v.signum() > 0) {
            row(sb, label, v);
        }
        return v;
    }

    private static String name(Employee emp) {
        return emp == null ? "" : asString(emp.getFullName());
    }

    /** "2026-27" → "2027-28"; tolerant of a single-year or blank input. */
    static String assessmentYear(String fy) {
        if (fy == null || fy.isBlank()) return "";
        String start = fy.contains("-") ? fy.substring(0, fy.indexOf('-')) : fy;
        try {
            int y = Integer.parseInt(start.trim());
            return (y + 1) + "-" + ((y + 2) % 100);
        } catch (NumberFormatException e) {
            return "";
        }
    }

    private static String css() {
        return "@page{size:A4;margin:18mm 16mm;}"
                + "body{font-family:'Helvetica','Arial',sans-serif;font-size:10px;color:#222;}"
                + ".banner{background:#1f2937;color:#fff;text-align:center;padding:8px;font-weight:700;font-size:12px;}"
                + ".subbanner{text-align:center;padding:6px 0 12px;color:#444;}"
                + ".hdr{width:100%;border-collapse:collapse;margin-bottom:14px;}"
                + ".hdr-cell{border:1px solid #d1d5db;padding:8px;vertical-align:top;}"
                + ".section-title{font-weight:700;background:#f3f4f6;padding:3px 6px;margin:-8px -8px 6px;font-size:11px;}"
                + ".val{font-size:11px;}.val.small{font-size:9px;color:#555;}"
                + ".part-title{background:#374151;color:#fff;padding:6px 8px;font-weight:700;font-size:11px;margin:12px 0 0;}"
                + ".data{width:100%;border-collapse:collapse;margin-bottom:6px;border:1px solid #d1d5db;}"
                + ".data th,.data td{padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:10px;}"
                + ".data th{background:#f3f4f6;text-align:left;font-weight:600;}"
                + ".data th.num,.data td.num{text-align:right;font-family:'Courier New',monospace;}"
                + ".data tr.tot td{font-weight:700;background:#f9fafb;}"
                + ".nil{padding:5px 8px;color:#777;font-style:italic;font-size:10px;}"
                + ".note{color:#777;font-style:italic;font-weight:400;}"
                + ".miss{color:#92400e;}"
                + ".words{padding:8px;background:#f3f4f6;border:1px solid #e5e7eb;margin:8px 0;font-style:italic;}"
                + ".warn{padding:6px 8px;background:#fef3e2;border:1px solid #f6d9a8;color:#92400e;margin:10px 0;font-size:10px;}"
                + ".status{margin:12px 0 4px;font-size:10px;color:#374151;}"
                + ".verification{margin-top:14px;padding:8px;border:1px solid #d1d5db;font-size:10px;}"
                + ".sign{margin-top:14px;font-size:10px;}"
                + ".footer{margin-top:16px;text-align:center;font-size:9px;color:#666;}";
    }

    private static BigDecimal asMoney(Object o) {
        if (o == null) return BigDecimal.ZERO;
        if (o instanceof BigDecimal b) return b.setScale(2, RoundingMode.HALF_UP);
        if (o instanceof Number n) return BigDecimal.valueOf(n.doubleValue()).setScale(2, RoundingMode.HALF_UP);
        return new BigDecimal(o.toString()).setScale(2, RoundingMode.HALF_UP);
    }

    private static String asString(Object o) { return o == null ? "" : o.toString(); }

    /** Indian rupee grouping: 1,23,456.78. */
    private static String formatMoney(BigDecimal v) {
        if (v == null) v = BigDecimal.ZERO;
        BigDecimal val = v.setScale(2, RoundingMode.HALF_UP);
        String[] split = val.toPlainString().split("\\.");
        String intPart = split[0];
        String frac = split.length > 1 ? split[1] : "00";
        String sign = "";
        if (intPart.startsWith("-")) { sign = "-"; intPart = intPart.substring(1); }
        StringBuilder out = new StringBuilder();
        int len = intPart.length();
        if (len <= 3) {
            out.append(intPart);
        } else {
            String last3 = intPart.substring(len - 3);
            String rest = intPart.substring(0, len - 3);
            StringBuilder grouped = new StringBuilder();
            int n = rest.length();
            for (int i = n; i > 0; i -= 2) {
                int from = Math.max(0, i - 2);
                if (grouped.length() > 0) grouped.insert(0, ",");
                grouped.insert(0, rest.substring(from, i));
            }
            out.append(grouped).append(",").append(last3);
        }
        return "₹ " + sign + out + "." + frac;
    }

    private static String esc(String s) {
        if (s == null) return "";
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '<' -> sb.append("&lt;");
                case '>' -> sb.append("&gt;");
                case '&' -> sb.append("&amp;");
                case '"' -> sb.append("&quot;");
                case '\'' -> sb.append("&#39;");
                default -> sb.append(c);
            }
        }
        return sb.toString();
    }
}
