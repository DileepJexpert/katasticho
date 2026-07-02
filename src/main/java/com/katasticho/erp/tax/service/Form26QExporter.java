package com.katasticho.erp.tax.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;

/**
 * Export-format adapter on top of {@link TdsService#form26q} — the vendor-TDS
 * mirror of {@link Form24QExporter}. Turns the structured Form 26Q data into
 * (a) a CSV register a CA opens first and (b) an NSDL FVU "deductee detail"
 * (DD) `^`-separated block for the govt RPU/FVU tool.
 *
 * <p>Unlike the salary 24Q — which hardcodes section "192" — 26Q carries the
 * real per-deductee section (194C / 194J / 194I / 194H / 194A / 194Q) and maps
 * it to the FVU two/three-character analysis code (94C, 94J, ...). Each DD row
 * also carries the deductee code (01 company / 02 non-company, inferred from
 * the 4th char of the PAN) and substitutes the {@code PANNOTAVBL} sentinel for
 * a blank PAN so the FVU doesn't reject the row.
 *
 * <p>The full FH/BH/CD/DD file needs the deductor TAN plus per-quarter ITNS-281
 * challan capture, which — exactly as the 24Q side notes — is not yet modelled.
 * Until that lands this ships the DD block + CSV register, which a CA mass-loads
 * into the RPU.
 */
@Service
@RequiredArgsConstructor
public class Form26QExporter {

    private static final String SEP = "^";
    private static final String EOL = "\r\n";
    /** FVU rejects a blank deductee PAN — file the "not available" sentinel. */
    private static final String PAN_NOT_AVAILABLE = "PANNOTAVBL";

    private final TdsService tdsService;

    /** CSV register — auditors and CAs open this first. */
    @Transactional(readOnly = true)
    public String csv(int fyStartYear, int quarter) {
        Map<String, Object> data = tdsService.form26q(fyStartYear, quarter);
        List<Map<String, Object>> deductees = deductees(data);

        StringBuilder sb = new StringBuilder();
        sb.append("Sr.,Vendor,PAN,Section,Amount Paid,TDS Deducted,Bills,Effective Rate %")
          .append(EOL);

        int sr = 1;
        for (Map<String, Object> d : deductees) {
            BigDecimal paid = asMoney(d.get("amountPaid"));
            BigDecimal tds = asMoney(d.get("tdsDeducted"));
            sb.append(sr++).append(",")
              .append(escapeCsv(asString(d.get("deducteeName")))).append(",")
              .append(escapeCsv(panOrSentinel(asString(d.get("deducteePan"))))).append(",")
              .append(escapeCsv(asString(d.get("section")))).append(",")
              .append(paid).append(",")
              .append(tds).append(",")
              .append(d.getOrDefault("billCount", 0)).append(",")
              .append(effectiveRate(paid, tds))
              .append(EOL);
        }
        sb.append(",,,TOTAL,")
          .append(asMoney(data.get("totalAmountPaid"))).append(",")
          .append(asMoney(data.get("totalTdsDeducted"))).append(",,").append(EOL);
        return sb.toString();
    }

    /**
     * NSDL FVU deductee-detail (DD) block — one `^`-separated record per
     * (vendor, section) group. Columns: line, "DD", deductee code (01/02),
     * PAN, name, FVU section code, amount paid, TDS deducted, effective rate.
     * Prepend FH/BH/CD headers in the FVU tool before upload.
     */
    @Transactional(readOnly = true)
    public String fvuDeducteeDetail(int fyStartYear, int quarter) {
        Map<String, Object> data = tdsService.form26q(fyStartYear, quarter);
        List<Map<String, Object>> deductees = deductees(data);

        StringBuilder sb = new StringBuilder();
        int line = 1;
        for (Map<String, Object> d : deductees) {
            BigDecimal paid = asMoney(d.get("amountPaid"));
            BigDecimal tds = asMoney(d.get("tdsDeducted"));
            String pan = panOrSentinel(asString(d.get("deducteePan")));
            sb.append(line++).append(SEP)
              .append("DD").append(SEP)
              .append(deducteeCode(pan)).append(SEP)
              .append(sanitiseFvu(pan)).append(SEP)
              .append(sanitiseFvu(asString(d.get("deducteeName")))).append(SEP)
              .append(fvuSectionCode(asString(d.get("section")))).append(SEP)
              .append(paid).append(SEP)
              .append(tds).append(SEP)
              .append(effectiveRate(paid, tds))
              .append(EOL);
        }
        return sb.toString();
    }

    public String filename(int fyStartYear, int quarter, String ext) {
        return "26Q-FY" + fyStartYear + "-Q" + quarter + "." + ext;
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> deductees(Map<String, Object> data) {
        return (List<Map<String, Object>>) data.getOrDefault("deductees", List.of());
    }

    private static String panOrSentinel(String pan) {
        return (pan == null || pan.isBlank()) ? PAN_NOT_AVAILABLE : pan.trim().toUpperCase();
    }

    /**
     * Deductee code: 01 = company, 02 = non-company. The 4th character of a
     * PAN encodes the holder type — 'C' is a company; everything else (P/H/F/
     * A/T/B/L/J/G) is treated as non-company. Sentinel PANs default to 02.
     */
    static String deducteeCode(String pan) {
        if (pan != null && pan.length() >= 4 && Character.toUpperCase(pan.charAt(3)) == 'C') {
            return "01";
        }
        return "02";
    }

    /** 194C → 94C, 194J → 94J, ... FVU uses the trailing analysis code. */
    static String fvuSectionCode(String section) {
        if (section == null) return "";
        String s = section.trim().toUpperCase();
        if (s.startsWith("194") && s.length() > 3) {
            return "94" + s.substring(3);
        }
        if (s.startsWith("19") && s.length() > 2) {
            return s.substring(1); // 192 → 92, 193 → 93 (defensive)
        }
        return s;
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
        return tds.multiply(new BigDecimal("100")).divide(paid, 2, RoundingMode.HALF_UP);
    }
}
