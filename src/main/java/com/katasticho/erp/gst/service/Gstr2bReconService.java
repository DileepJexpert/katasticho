package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * GSTR-2B reconciliation — match supplier-filed invoices (from the GST portal's
 * 2B JSON) against posted purchase bills, and surface every discrepancy in the
 * AI Inbox.
 *
 * <p>Outcomes per 2B row:
 * <ul>
 *   <li><b>MATCHED</b> — bill found, value within ₹1.</li>
 *   <li><b>VALUE_MISMATCH</b> — bill found but totals differ (possible ITC error).</li>
 *   <li><b>NOT_IN_BOOKS</b> — supplier filed it but no bill recorded (missed ITC).</li>
 * </ul>
 * Plus the reverse check: posted bills whose supplier did NOT file → ITC at
 * risk ("supplier not filed" list in the summary).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class Gstr2bReconService {

    /** Totals within this are considered equal (rounding on the portal side). */
    private static final BigDecimal VALUE_TOLERANCE = new BigDecimal("1.00");
    private static final DateTimeFormatter PORTAL_DATE = DateTimeFormatter.ofPattern("dd-MM-yyyy");

    private final Gstr2bEntryRepository entryRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final ContactRepository contactRepository;
    private final AiSuggestionService aiSuggestionService;

    // ── Upload + reconcile ───────────────────────────────────────────────

    /**
     * Replace the period's entries with rows parsed from the portal JSON,
     * reconcile them against purchase bills, and return the summary.
     */
    @Transactional
    public Map<String, Object> upload(String period, Map<String, Object> portalJson) {
        UUID orgId = requireOrgId();
        YearMonth ym = parsePeriod(period);

        List<Gstr2bEntry> parsed = parsePortalJson(orgId, ym.toString(), portalJson);
        if (parsed.isEmpty()) {
            throw new BusinessException(
                    "No B2B invoices found in the uploaded GSTR-2B JSON",
                    "GST_2B_EMPTY");
        }

        // Re-upload dedupe: clear the prior upload's un-actioned inbox items for
        // this period before replacing entries, so suggestions don't accumulate.
        List<Gstr2bEntry> prior = entryRepository
                .findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, ym.toString());
        if (!prior.isEmpty()) {
            aiSuggestionService.dismissPendingForEntities("GSTR2B_ENTRY",
                    prior.stream().map(Gstr2bEntry::getId).toList());
        }

        entryRepository.deleteByOrgIdAndReturnPeriod(orgId, ym.toString());
        List<Gstr2bEntry> saved = entryRepository.saveAll(parsed);
        reconcile(orgId, ym, saved);
        entryRepository.saveAll(saved);

        log.info("GSTR-2B {}: {} entries uploaded and reconciled for org {}",
                ym, saved.size(), orgId);
        return summary(period);
    }

    @Transactional(readOnly = true)
    public List<Gstr2bEntry> list(String period) {
        UUID orgId = requireOrgId();
        return entryRepository.findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(
                orgId, parsePeriod(period).toString());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> summary(String period) {
        UUID orgId = requireOrgId();
        YearMonth ym = parsePeriod(period);
        List<Gstr2bEntry> entries = entryRepository
                .findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, ym.toString());

        long matched = 0, mismatched = 0, notInBooks = 0;
        BigDecimal matchedItc = BigDecimal.ZERO, mismatchItc = BigDecimal.ZERO, missingItc = BigDecimal.ZERO;
        Set<UUID> matchedBillIds = new HashSet<>();
        for (Gstr2bEntry e : entries) {
            switch (e.getMatchStatus()) {
                case "MATCHED" -> { matched++; matchedItc = matchedItc.add(e.totalTax()); }
                case "VALUE_MISMATCH" -> { mismatched++; mismatchItc = mismatchItc.add(e.totalTax()); }
                case "NOT_IN_BOOKS" -> { notInBooks++; missingItc = missingItc.add(e.totalTax()); }
                default -> { /* UNMATCHED before reconcile — counted nowhere */ }
            }
            if (e.getMatchedBillId() != null) {
                matchedBillIds.add(e.getMatchedBillId());
            }
        }

        List<Map<String, Object>> supplierNotFiled = findSupplierNotFiled(orgId, ym, matchedBillIds);
        BigDecimal itcAtRisk = supplierNotFiled.stream()
                .map(m -> (BigDecimal) m.get("itc"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("period", ym.toString());
        result.put("totalEntries", entries.size());
        result.put("matched", matched);
        result.put("valueMismatch", mismatched);
        result.put("notInBooks", notInBooks);
        result.put("matchedItc", matchedItc);
        result.put("mismatchItc", mismatchItc);
        result.put("missingItc", missingItc);
        result.put("supplierNotFiled", supplierNotFiled);
        result.put("itcAtRisk", itcAtRisk);
        return result;
    }

    // ── Matching ─────────────────────────────────────────────────────────

    private void reconcile(UUID orgId, YearMonth period, List<Gstr2bEntry> entries) {
        // Suppliers may file late or bills get entered early/late — search a
        // window around the period rather than the period alone.
        LocalDate from = period.atDay(1).minusMonths(2);
        LocalDate to = period.atEndOfMonth().plusMonths(1);
        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(orgId, from, to);
        Map<UUID, Contact> vendors = loadVendors(orgId, bills);

        // Index bills by supplier GSTIN + normalized vendor invoice number.
        Map<String, PurchaseBill> billIndex = new HashMap<>();
        for (PurchaseBill bill : bills) {
            Contact vendor = vendors.get(bill.getContactId());
            if (vendor == null || isBlank(vendor.getGstin()) || isBlank(bill.getVendorBillNumber())) {
                continue;
            }
            billIndex.putIfAbsent(
                    matchKey(vendor.getGstin(), bill.getVendorBillNumber()), bill);
        }

        for (Gstr2bEntry entry : entries) {
            PurchaseBill bill = billIndex.get(matchKey(entry.getSupplierGstin(), entry.getInvoiceNumber()));
            if (bill == null) {
                entry.setMatchStatus("NOT_IN_BOOKS");
                entry.setMatchNote("Supplier filed this invoice but it is not recorded in your books — "
                        + "ITC of " + entry.totalTax().toPlainString() + " is unclaimed until you record it.");
                createSuggestion(orgId, entry, "GSTR2B_MISSING_BILL", "HIGH",
                        "Supplier " + displayName(entry) + " filed invoice " + entry.getInvoiceNumber()
                                + " (" + entry.getInvoiceValue().toPlainString() + ") in GSTR-2B "
                                + entry.getReturnPeriod() + ", but no matching purchase bill exists. "
                                + "Record the bill to claim ITC of " + entry.totalTax().toPlainString() + ".");
                continue;
            }

            entry.setMatchedBillId(bill.getId());
            BigDecimal diff = entry.getInvoiceValue().subtract(nz(bill.getTotalAmount())).abs();
            if (diff.compareTo(VALUE_TOLERANCE) <= 0) {
                entry.setMatchStatus("MATCHED");
                entry.setMatchNote("Matched " + bill.getBillNumber());
            } else {
                entry.setMatchStatus("VALUE_MISMATCH");
                entry.setMatchNote("Matched " + bill.getBillNumber() + " but values differ: 2B says "
                        + entry.getInvoiceValue().toPlainString() + ", books say "
                        + nz(bill.getTotalAmount()).toPlainString() + " (diff " + diff.toPlainString() + ").");
                createSuggestion(orgId, entry, "GSTR2B_VALUE_MISMATCH", "HIGH",
                        "GSTR-2B value for " + displayName(entry) + " invoice " + entry.getInvoiceNumber()
                                + " is " + entry.getInvoiceValue().toPlainString() + " but bill "
                                + bill.getBillNumber() + " in books is "
                                + nz(bill.getTotalAmount()).toPlainString()
                                + ". Verify before claiming ITC — a wrong claim invites notice.");
            }
        }
    }

    /** Posted bills inside the period whose registered supplier did NOT file. */
    private List<Map<String, Object>> findSupplierNotFiled(UUID orgId, YearMonth period,
                                                           Set<UUID> matchedBillIds) {
        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(
                orgId, period.atDay(1), period.atEndOfMonth());
        Map<UUID, Contact> vendors = loadVendors(orgId, bills);

        List<Map<String, Object>> rows = new ArrayList<>();
        for (PurchaseBill bill : bills) {
            if (matchedBillIds.contains(bill.getId())) continue;
            Contact vendor = vendors.get(bill.getContactId());
            if (vendor == null || isBlank(vendor.getGstin())) continue; // unregistered — no 2B expected
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("billId", bill.getId());
            row.put("billNumber", bill.getBillNumber());
            row.put("vendorBillNumber", bill.getVendorBillNumber());
            row.put("vendorName", vendor.getDisplayName());
            row.put("vendorGstin", vendor.getGstin());
            row.put("billDate", bill.getBillDate());
            row.put("totalAmount", nz(bill.getTotalAmount()));
            row.put("itc", nz(bill.getTaxAmount()));
            rows.add(row);
        }
        return rows;
    }

    private void createSuggestion(UUID orgId, Gstr2bEntry entry, String type,
                                  String priority, String reasoning) {
        try {
            Map<String, Object> value = new LinkedHashMap<>();
            value.put("period", entry.getReturnPeriod());
            value.put("supplierGstin", entry.getSupplierGstin());
            value.put("supplierName", entry.getSupplierName());
            value.put("invoiceNumber", entry.getInvoiceNumber());
            value.put("invoiceValue", entry.getInvoiceValue().toPlainString());
            value.put("itc", entry.totalTax().toPlainString());
            if (entry.getMatchedBillId() != null) {
                value.put("matchedBillId", entry.getMatchedBillId().toString());
            }
            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .orgId(orgId)
                    .entityType("GSTR2B_ENTRY")
                    .entityId(entry.getId())
                    .suggestionType(type)
                    .suggestedAction("REVIEW_GSTR2B_ENTRY")
                    .suggestedValue(value)
                    .reasoning(reasoning)
                    .confidence(new BigDecimal("0.900"))
                    .agentName("gst_recon")
                    .modelName("deterministic_rules")
                    .modelVersion("1")
                    .promptVersion("none")
                    .priority(priority)
                    .priorityScore(new BigDecimal("75"))
                    .status("PENDING")
                    .build());
        } catch (Exception e) {
            // Reconciliation results must persist even if the inbox write fails.
            log.warn("Could not create GSTR-2B suggestion for entry {}: {}", entry.getId(), e.getMessage());
        }
    }

    // ── Portal JSON parsing ──────────────────────────────────────────────

    /**
     * Parse the GST portal's GSTR-2B JSON. Accepts the official shape
     * ({@code data.docdata.b2b[].inv[]}) and a simplified {@code entries[]}
     * list (useful for CSV-converted or hand-built files).
     */
    @SuppressWarnings("unchecked")
    List<Gstr2bEntry> parsePortalJson(UUID orgId, String period, Map<String, Object> json) {
        List<Gstr2bEntry> out = new ArrayList<>();
        if (json == null) return out;

        Object simplified = json.get("entries");
        if (simplified instanceof List<?> list) {
            for (Object o : list) {
                if (o instanceof Map<?, ?> m) {
                    out.add(fromSimplified(orgId, period, (Map<String, Object>) m));
                }
            }
            return out;
        }

        Object data = json.getOrDefault("data", json);
        Object docdata = data instanceof Map<?, ?> dm ? ((Map<String, Object>) dm).get("docdata") : null;
        Object b2b = docdata instanceof Map<?, ?> dd ? ((Map<String, Object>) dd).get("b2b") : null;
        if (!(b2b instanceof List<?> suppliers)) return out;

        for (Object supplierObj : suppliers) {
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
                        Map<String, Object> item = (Map<String, Object>) itemRaw;
                        taxable = taxable.add(num(item.get("txval")));
                        igst = igst.add(num(item.get("igst")));
                        cgst = cgst.add(num(item.get("cgst")));
                        sgst = sgst.add(num(item.get("sgst")));
                        cess = cess.add(num(item.get("cess")));
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
                        .itcAvailable(!"N".equalsIgnoreCase(str(inv.get("itcavl"))))
                        .build());
            }
        }
        return out;
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
                .igst(num(m.get("igst")))
                .cgst(num(m.get("cgst")))
                .sgst(num(m.get("sgst")))
                .cess(num(m.get("cess")))
                .build();
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    /** GSTIN + invoice number normalized: uppercase, alphanumeric only, no leading zeros. */
    static String matchKey(String gstin, String invoiceNumber) {
        String num = invoiceNumber == null ? "" : invoiceNumber.toUpperCase().replaceAll("[^A-Z0-9]", "");
        num = num.replaceFirst("^0+(?=.)", "");
        return (gstin == null ? "" : gstin.trim().toUpperCase()) + "|" + num;
    }

    private Map<UUID, Contact> loadVendors(UUID orgId, List<PurchaseBill> bills) {
        Set<UUID> ids = new HashSet<>();
        bills.forEach(b -> ids.add(b.getContactId()));
        if (ids.isEmpty()) return Map.of();
        Map<UUID, Contact> map = new HashMap<>();
        contactRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, ids)
                .forEach(c -> map.put(c.getId(), c));
        return map;
    }

    private YearMonth parsePeriod(String period) {
        try {
            return YearMonth.parse(period);
        } catch (Exception e) {
            throw new BusinessException(
                    "Period must be YYYY-MM, e.g. 2026-05", "GST_2B_BAD_PERIOD");
        }
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

    private String displayName(Gstr2bEntry e) {
        return isBlank(e.getSupplierName()) ? e.getSupplierGstin() : e.getSupplierName();
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

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
