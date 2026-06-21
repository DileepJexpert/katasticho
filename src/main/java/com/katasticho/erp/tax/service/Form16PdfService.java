package com.katasticho.erp.tax.service;

import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.common.util.AmountToWordsConverter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Renders Form 16 (employee TDS certificate, Sec 203 IT Act) as a PDF from
 * the structured data in {@link SalaryTdsService#form16(UUID, int)}. The
 * employer issues this annually to every employee with salary TDS.
 *
 * <p>Layout follows the CBDT Form 16 template:
 * <ul>
 *   <li><b>Header</b> — deductor (employer) name/address/TAN/PAN; employee
 *       name/PAN/designation; FY + Assessment Year.</li>
 *   <li><b>Part A</b> — quarter-wise TDS deducted + remitted.</li>
 *   <li><b>Part B</b> — gross salary breakup by component, exemptions,
 *       deductions, total tax deducted, tax in words.</li>
 * </ul>
 *
 * <p>HTML → PDF via the shared {@link DocumentPdfService} (open-html-to-pdf),
 * matching the BMR/invoice/payslip pipelines.
 */
@Service
@RequiredArgsConstructor
public class Form16PdfService {

    private final SalaryTdsService salaryTdsService;
    private final DocumentPdfService pdfService;

    @Transactional(readOnly = true)
    public byte[] generatePdf(UUID employeeId, int fyStartYear) {
        Map<String, Object> data = salaryTdsService.form16(employeeId, fyStartYear);
        return pdfService.render(buildHtml(data));
    }

    public String filename(int fyStartYear, String employeeName) {
        String name = employeeName == null || employeeName.isBlank()
                ? "Employee" : employeeName.replaceAll("[\\\\/:*?\"<>|]", " ").trim();
        return "Form16-" + name + "-FY" + fyStartYear + "-" + ((fyStartYear + 1) % 100) + ".pdf";
    }

    // ── HTML builder ──────────────────────────────────────────────

    String buildHtml(Map<String, Object> data) {
        @SuppressWarnings("unchecked")
        Map<String, Object> employee = (Map<String, Object>) data.getOrDefault("employee", Map.of());
        @SuppressWarnings("unchecked")
        Map<String, Object> deductor = (Map<String, Object>) data.getOrDefault("deductor", Map.of());
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> partA = (List<Map<String, Object>>) data.getOrDefault("partA", List.of());
        @SuppressWarnings("unchecked")
        Map<String, Object> partB = (Map<String, Object>) data.getOrDefault("partB", Map.of());

        BigDecimal totalTds = asMoney(data.get("totalTdsDeducted"));

        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='utf-8'><style>")
          .append(css())
          .append("</style></head><body>");

        // Banner
        sb.append("<div class='banner'>FORM 16 — Certificate under section 203 of the Income-tax Act, 1961</div>");
        sb.append("<div class='subbanner'>FY ").append(esc(asString(data.get("fy"))))
          .append(" · Assessment Year ").append(esc(asString(data.get("assessmentYear"))))
          .append("</div>");

        // Deductor + Employee header block
        sb.append("<table class='hdr'>")
          .append("<tr>")
          .append("<td class='hdr-cell'>")
          .append("<div class='section-title'>Deductor (Employer)</div>")
          .append("<div class='val'>").append(esc(asString(deductor.get("name")))).append("</div>")
          .append("<div class='val small'>").append(esc(asString(deductor.get("address")))).append("</div>")
          .append("<div class='val small'>TAN: ").append(esc(asString(deductor.get("tan")))).append("</div>")
          .append("<div class='val small'>PAN: ").append(esc(asString(deductor.get("pan")))).append("</div>")
          .append("</td>")
          .append("<td class='hdr-cell'>")
          .append("<div class='section-title'>Deductee (Employee)</div>")
          .append("<div class='val'>").append(esc(asString(employee.get("name")))).append("</div>")
          .append("<div class='val small'>Employee Code: ").append(esc(asString(employee.get("employeeCode")))).append("</div>")
          .append("<div class='val small'>Designation: ").append(esc(asString(employee.get("designation")))).append("</div>")
          .append("<div class='val small'>PAN: ").append(esc(asString(employee.get("pan")))).append("</div>")
          .append("</td>")
          .append("</tr></table>");

        // Part A — quarter-wise TDS
        sb.append("<div class='part-title'>PART A — Tax Deducted at Source &amp; Deposited</div>");
        sb.append("<table class='data'><thead><tr>")
          .append("<th>Quarter</th><th class='num'>TDS Deducted (₹)</th>")
          .append("</tr></thead><tbody>");
        BigDecimal qSum = BigDecimal.ZERO;
        for (Map<String, Object> row : partA) {
            BigDecimal tds = asMoney(row.get("tdsDeducted"));
            qSum = qSum.add(tds);
            sb.append("<tr>")
              .append("<td>").append(esc(asString(row.get("quarter")))).append("</td>")
              .append("<td class='num'>").append(formatMoney(tds)).append("</td>")
              .append("</tr>");
        }
        sb.append("<tr class='tot'>")
          .append("<td>Total</td>")
          .append("<td class='num'>").append(formatMoney(qSum)).append("</td>")
          .append("</tr>");
        sb.append("</tbody></table>");

        // Part B — salary breakup
        sb.append("<div class='part-title'>PART B — Details of Salary Paid &amp; Tax Deducted</div>");
        @SuppressWarnings("unchecked")
        Map<String, Object> earningsMap = (Map<String, Object>) partB.getOrDefault("earningsByComponent", Map.of());
        @SuppressWarnings("unchecked")
        Map<String, Object> deductionsMap = (Map<String, Object>) partB.getOrDefault("deductionsByComponent", Map.of());

        BigDecimal grossSalary = asMoney(partB.get("grossSalary"));
        BigDecimal professionalTax = asMoney(partB.get("professionalTax"));

        sb.append("<div class='subhdr'>1. Gross Salary</div>");
        sb.append("<table class='data'><tbody>");
        for (Map.Entry<String, Object> e : earningsMap.entrySet()) {
            sb.append("<tr>")
              .append("<td>").append(esc(prettyComponent(e.getKey()))).append("</td>")
              .append("<td class='num'>").append(formatMoney(asMoney(e.getValue()))).append("</td>")
              .append("</tr>");
        }
        sb.append("<tr class='tot'>")
          .append("<td>Gross salary</td>")
          .append("<td class='num'>").append(formatMoney(grossSalary)).append("</td>")
          .append("</tr></tbody></table>");

        sb.append("<div class='subhdr'>2. Deductions from Salary</div>");
        sb.append("<table class='data'><tbody>");
        for (Map.Entry<String, Object> e : deductionsMap.entrySet()) {
            // skip TDS in this section — it's reported separately at the bottom
            if ("TDS".equalsIgnoreCase(e.getKey())) continue;
            sb.append("<tr>")
              .append("<td>").append(esc(prettyComponent(e.getKey()))).append("</td>")
              .append("<td class='num'>").append(formatMoney(asMoney(e.getValue()))).append("</td>")
              .append("</tr>");
        }
        if (professionalTax.signum() > 0) {
            sb.append("<tr><td>Tax on employment (Sec 16(iii))</td><td class='num'>")
              .append(formatMoney(professionalTax)).append("</td></tr>");
        }
        sb.append("</tbody></table>");

        // Total tax block
        sb.append("<div class='subhdr'>3. Tax Deducted at Source</div>");
        sb.append("<table class='data'><tbody>")
          .append("<tr class='tot'><td>Total tax deducted (Sec 192)</td><td class='num'>")
          .append(formatMoney(totalTds)).append("</td></tr>")
          .append("</tbody></table>");

        if (totalTds.signum() > 0) {
            sb.append("<div class='words'>")
              .append(esc(AmountToWordsConverter.convert(totalTds)))
              .append("</div>");
        }

        // Optional warning (no PAN, etc.)
        if (data.get("warning") != null) {
            sb.append("<div class='warn'>⚠ ")
              .append(esc(asString(data.get("warning"))))
              .append("</div>");
        }

        sb.append("<div class='footer'>")
          .append("This Form 16 is system-generated from posted payroll runs for the financial year. ")
          .append("Generated on ").append(esc(java.time.LocalDate.now().toString())).append(".")
          .append("</div>");

        sb.append("</body></html>");
        return sb.toString();
    }

    // ── helpers ──────────────────────────────────────────────────

    private static String css() {
        return "@page{size:A4;margin:18mm 16mm;}"
                + "body{font-family:'Helvetica','Arial',sans-serif;font-size:10px;color:#222;}"
                + ".banner{background:#1f2937;color:#fff;text-align:center;padding:8px;font-weight:700;font-size:12px;}"
                + ".subbanner{text-align:center;padding:6px 0 12px;color:#444;}"
                + ".hdr{width:100%;border-collapse:collapse;margin-bottom:14px;}"
                + ".hdr-cell{border:1px solid #d1d5db;padding:8px;vertical-align:top;width:50%;}"
                + ".section-title{font-weight:700;background:#f3f4f6;padding:3px 6px;margin:-8px -8px 6px;font-size:11px;}"
                + ".val{font-size:11px;}.val.small{font-size:9px;color:#555;}"
                + ".part-title{background:#374151;color:#fff;padding:6px 8px;font-weight:700;font-size:11px;margin:12px 0 0;}"
                + ".subhdr{font-weight:600;padding:6px 0 4px;font-size:11px;color:#374151;}"
                + ".data{width:100%;border-collapse:collapse;margin-bottom:6px;border:1px solid #d1d5db;}"
                + ".data th,.data td{padding:4px 8px;border-bottom:1px solid #e5e7eb;font-size:10px;}"
                + ".data th{background:#f3f4f6;text-align:left;font-weight:600;}"
                + ".data th.num,.data td.num{text-align:right;font-family:'Courier New',monospace;}"
                + ".data tr.tot td{font-weight:700;background:#f9fafb;}"
                + ".words{padding:8px;background:#f3f4f6;border:1px solid #e5e7eb;margin:8px 0;font-style:italic;}"
                + ".warn{padding:6px 8px;background:#fef3e2;border:1px solid #f6d9a8;color:#92400e;margin:10px 0;font-size:10px;}"
                + ".footer{margin-top:16px;text-align:center;font-size:9px;color:#666;}";
    }

    private static String prettyComponent(String code) {
        return switch (code == null ? "" : code.toUpperCase()) {
            case "BASIC" -> "Basic";
            case "HRA" -> "House Rent Allowance";
            case "DA" -> "Dearness Allowance";
            case "CONV", "CONVEYANCE" -> "Conveyance Allowance";
            case "SPL", "SPECIAL" -> "Special Allowance";
            case "LTA" -> "Leave Travel Allowance";
            case "PF_EMPLOYEE", "PF" -> "Provident Fund";
            case "ESI", "ESI_EMPLOYEE" -> "Employees' State Insurance";
            case "PT" -> "Professional Tax";
            case "LWF" -> "Labour Welfare Fund";
            case "TDS" -> "Tax Deducted at Source";
            default -> code == null ? "" : code;
        };
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
