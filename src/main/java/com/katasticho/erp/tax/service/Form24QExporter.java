package com.katasticho.erp.tax.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;

/**
 * Export-format adapter on top of {@link SalaryTdsService}. The data layer
 * (structured Map) already exists; this turns it into a CSV for auditors
 * and a `^`-separated text in the NSDL FVU "deductee detail" record shape
 * so the user can wrap it with the FVU header/batch blocks for portal
 * upload.
 *
 * <p>The full NSDL FVU plain text is a multi-record, fixed-column format
 * (File Header FH, Batch Header BH, Challan Header CH, Deductee Detail DD).
 * Generating the complete file requires the employer's TAN, challan numbers,
 * and a few other org-level fields that aren't yet captured. Until those
 * land, this exporter ships the DD block plus a CSV register that every
 * CA can hand-mass-import into FVU.
 */
@Service
@RequiredArgsConstructor
public class Form24QExporter {

    private static final String SEP = "^";
    private static final String EOL = "\r\n";

    private final SalaryTdsService salaryTdsService;

    /** CSV register — auditors and CAs open this first. */
    @Transactional(readOnly = true)
    public String csv(int fyStartYear, int quarter) {
        Map<String, Object> data = salaryTdsService.form24q(fyStartYear, quarter);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> deductees =
                (List<Map<String, Object>>) data.getOrDefault("deductees", List.of());

        StringBuilder sb = new StringBuilder();
        sb.append("Sr.,Employee Code,Employee Name,PAN,Amount Paid,TDS Deducted,Months,Effective Rate %")
          .append(EOL);

        int sr = 1;
        for (Map<String, Object> d : deductees) {
            BigDecimal paid = asMoney(d.get("amountPaid"));
            BigDecimal tds = asMoney(d.get("tdsDeducted"));
            sb.append(sr++).append(",")
              .append(escapeCsv(asString(d.get("employeeCode")))).append(",")
              .append(escapeCsv(asString(d.get("deducteeName")))).append(",")
              .append(escapeCsv(asString(d.get("deducteePan")))).append(",")
              .append(paid).append(",")
              .append(tds).append(",")
              .append(d.getOrDefault("monthCount", 0)).append(",")
              .append(effectiveRate(paid, tds))
              .append(EOL);
        }
        // Totals row
        sb.append(",,,TOTAL,")
          .append(asMoney(data.get("totalAmountPaid"))).append(",")
          .append(asMoney(data.get("totalTdsDeducted"))).append(",,").append(EOL);
        return sb.toString();
    }

    /**
     * NSDL FVU deductee-detail (DD) block — `^`-separated records, one per
     * employee. Columns: line, deductee ref (auto-generated from employee
     * code/UUID), PAN, deductee name, section ("192" for salary), amount
     * paid, TDS deducted, effective rate.
     *
     * <p>Prepend with FH/BH/CH headers in your FVU tool before upload.
     */
    @Transactional(readOnly = true)
    public String fvuDeducteeDetail(int fyStartYear, int quarter) {
        Map<String, Object> data = salaryTdsService.form24q(fyStartYear, quarter);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> deductees =
                (List<Map<String, Object>>) data.getOrDefault("deductees", List.of());

        StringBuilder sb = new StringBuilder();
        int line = 1;
        for (Map<String, Object> d : deductees) {
            BigDecimal paid = asMoney(d.get("amountPaid"));
            BigDecimal tds = asMoney(d.get("tdsDeducted"));
            sb.append(line++).append(SEP)
              .append("DD").append(SEP)                                       // record type
              .append(sanitiseFvu(asString(d.get("employeeCode")))).append(SEP)
              .append(sanitiseFvu(asString(d.get("deducteePan")))).append(SEP)
              .append(sanitiseFvu(asString(d.get("deducteeName")))).append(SEP)
              .append("192").append(SEP)                                      // section: salary
              .append(paid).append(SEP)
              .append(tds).append(SEP)
              .append(effectiveRate(paid, tds))
              .append(EOL);
        }
        return sb.toString();
    }

    public String filename(int fyStartYear, int quarter, String ext) {
        return "24Q-FY" + fyStartYear + "-Q" + quarter + "." + ext;
    }

    private static String escapeCsv(String s) {
        if (s == null) return "";
        return s.contains(",") || s.contains("\"") || s.contains("\n")
                ? "\"" + s.replace("\"", "\"\"") + "\""
                : s;
    }

    private static String sanitiseFvu(String s) {
        if (s == null) return "";
        return s.replace(SEP, " ").replace("\r", " ").replace("\n", " ").trim();
    }

    private static BigDecimal asMoney(Object o) {
        if (o == null) return BigDecimal.ZERO;
        if (o instanceof BigDecimal b) return b.setScale(2, RoundingMode.HALF_UP);
        if (o instanceof Number n) return BigDecimal.valueOf(n.doubleValue()).setScale(2, RoundingMode.HALF_UP);
        return new BigDecimal(o.toString()).setScale(2, RoundingMode.HALF_UP);
    }

    private static String asString(Object o) {
        return o == null ? "" : o.toString();
    }

    private static BigDecimal effectiveRate(BigDecimal paid, BigDecimal tds) {
        if (paid == null || paid.signum() == 0) {
            return BigDecimal.ZERO.setScale(2);
        }
        return tds.multiply(new BigDecimal("100"))
                .divide(paid, 2, RoundingMode.HALF_UP);
    }
}
