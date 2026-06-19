package com.katasticho.erp.gst.service;

import com.katasticho.erp.gst.entity.Gstr2bEntry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Parser for the GSTR-2A JSON — the real-time, continuously-updating feed the
 * ITC-at-risk monitor reads (vs the frozen 2B the reconciler parses).
 *
 * <p>2A's shape differs from 2B in ways the 2B parser would silently drop:
 * <ul>
 *   <li>tax keys are {@code iamt/camt/samt/csamt} (not {@code igst/cgst/sgst/cess})</li>
 *   <li>item tax is nested under {@code itm_det}</li>
 *   <li>the {@code b2b} array sits at {@code data.b2b} (or top-level), not
 *       {@code data.docdata.b2b}</li>
 *   <li>each supplier carries {@code cfs} — counterparty filing status</li>
 * </ul>
 *
 * <p>An invoice's <em>presence</em> in 2A means the supplier reported it, which
 * is exactly the signal the monitor needs. Output rows reuse {@link Gstr2bEntry}
 * so the existing reconcile/store path is unchanged.
 */
@Component
@Slf4j
public class Gstr2aParser {

    private static final DateTimeFormatter PORTAL_DATE = DateTimeFormatter.ofPattern("dd-MM-yyyy");

    @SuppressWarnings("unchecked")
    public List<Gstr2bEntry> parse(UUID orgId, String period, Map<String, Object> json) {
        List<Gstr2bEntry> out = new ArrayList<>();
        if (json == null) return out;

        // Hand-built / CSV-converted simplified shape: { "entries": [ {...} ] }.
        Object simplified = json.get("entries");
        if (simplified instanceof List<?> list) {
            for (Object o : list) {
                if (o instanceof Map<?, ?> m) out.add(fromSimplified(orgId, period, (Map<String, Object>) m));
            }
            return out;
        }

        for (Object supplierObj : locateB2b(json)) {
            if (!(supplierObj instanceof Map<?, ?> supplierRaw)) continue;
            Map<String, Object> supplier = (Map<String, Object>) supplierRaw;
            String ctin = str(supplier.get("ctin"));
            String name = str(supplier.get("trdnm"));
            Object invList = supplier.get("inv");
            if (ctin == null || !(invList instanceof List<?> invoices)) continue;

            for (Object invObj : invoices) {
                if (!(invObj instanceof Map<?, ?> invRaw)) continue;
                Map<String, Object> inv = (Map<String, Object>) invRaw;
                String inum = str(inv.get("inum"));
                if (inum == null) continue;

                BigDecimal taxable = BigDecimal.ZERO, igst = BigDecimal.ZERO,
                        cgst = BigDecimal.ZERO, sgst = BigDecimal.ZERO, cess = BigDecimal.ZERO;
                if (inv.get("itms") instanceof List<?> items) {
                    for (Object itemObj : items) {
                        if (!(itemObj instanceof Map<?, ?> itemRaw)) continue;
                        // 2A nests the figures under itm_det; tolerate a flat shape too.
                        Map<String, Object> det = (Map<String, Object>) itemRaw;
                        if (det.get("itm_det") instanceof Map<?, ?> nested) {
                            det = (Map<String, Object>) nested;
                        }
                        taxable = taxable.add(num(det.get("txval")));
                        igst = igst.add(tax(det, "iamt", "igst"));
                        cgst = cgst.add(tax(det, "camt", "cgst"));
                        sgst = sgst.add(tax(det, "samt", "sgst"));
                        cess = cess.add(tax(det, "csamt", "cess"));
                    }
                }

                out.add(Gstr2bEntry.builder()
                        .orgId(orgId)
                        .returnPeriod(period)
                        .supplierGstin(ctin)
                        .supplierName(name)
                        .invoiceNumber(inum)
                        .invoiceDate(parseDate(str(inv.get("dt"))))
                        .invoiceValue(num(inv.get("val")))
                        .taxableValue(taxable)
                        .igst(igst).cgst(cgst).sgst(sgst).cess(cess)
                        .itcAvailable(true) // present in 2A ⇒ supplier reported it
                        .build());
            }
        }
        return out;
    }

    /** 2A puts b2b at data.b2b or top level; tolerate the 2B-style docdata nesting too. */
    @SuppressWarnings("unchecked")
    private List<?> locateB2b(Map<String, Object> json) {
        Object data = json.getOrDefault("data", json);
        Map<String, Object> dataMap = data instanceof Map<?, ?> dm ? (Map<String, Object>) dm : Map.of();
        if (dataMap.get("b2b") instanceof List<?> l) return l;
        if (json.get("b2b") instanceof List<?> l) return l;
        Object docdata = dataMap.get("docdata");
        if (docdata instanceof Map<?, ?> dd && ((Map<String, Object>) dd).get("b2b") instanceof List<?> l) {
            return l;
        }
        return List.of();
    }

    private Gstr2bEntry fromSimplified(UUID orgId, String period, Map<String, Object> m) {
        return Gstr2bEntry.builder()
                .orgId(orgId)
                .returnPeriod(period)
                .supplierGstin(str(m.get("supplierGstin")))
                .supplierName(str(m.get("supplierName")))
                .invoiceNumber(str(m.get("invoiceNumber")))
                .invoiceDate(parseDate(str(m.get("invoiceDate"))))
                .invoiceValue(num(m.get("invoiceValue")))
                .taxableValue(num(m.get("taxableValue")))
                .igst(tax(m, "iamt", "igst"))
                .cgst(tax(m, "camt", "cgst"))
                .sgst(tax(m, "samt", "sgst"))
                .cess(tax(m, "csamt", "cess"))
                .itcAvailable(true)
                .build();
    }

    /** Read a 2A tax key, falling back to the 2B-style key when a GSP normalizes. */
    private static BigDecimal tax(Map<String, Object> m, String key2a, String key2b) {
        Object v = m.get(key2a);
        if (v == null) v = m.get(key2b);
        return num(v);
    }

    private LocalDate parseDate(String s) {
        if (s == null || s.isBlank()) return null;
        try {
            return LocalDate.parse(s.trim(), PORTAL_DATE);
        } catch (Exception ignored) { }
        try {
            return LocalDate.parse(s.trim());
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String str(Object o) {
        if (o == null) return null;
        String s = o.toString().trim();
        return s.isEmpty() ? null : s;
    }

    private static BigDecimal num(Object o) {
        if (o == null) return BigDecimal.ZERO;
        try {
            return new BigDecimal(o.toString());
        } catch (NumberFormatException e) {
            return BigDecimal.ZERO;
        }
    }
}
