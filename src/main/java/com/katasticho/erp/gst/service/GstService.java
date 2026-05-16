package com.katasticho.erp.gst.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.CreditNote;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.CreditNoteRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GstService {

    private static final String GST_REGIME = "INDIA_GST";
    private static final String STATUS_DRAFT = "DRAFT";
    private static final String STATUS_CANCELLED = "CANCELLED";
    private static final String STATUS_VOID = "VOID";

    private final InvoiceRepository invoiceRepository;
    private final CreditNoteRepository creditNoteRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;

    // ── GSTR-1 ───────────────────────────────────────────────────────

    /**
     * Full GSTR-1 with B2B, B2CS, CDNR, CDN-UR, and HSN summary sections.
     * Format matches GSTN JSON API v1.1 structure.
     */
    public Map<String, Object> generateGstr1(int year, int month) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        String orgGstin = org != null && org.getGstin() != null ? org.getGstin() : "";

        LocalDate from = LocalDate.of(year, month, 1);
        LocalDate to = from.plusMonths(1).minusDays(1);

        // Invoices for the period (posted/sent/paid — exclude draft/cancelled)
        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(orgId, from, to);

        // Credit notes for the period
        List<CreditNote> creditNotes = creditNoteRepository
                .findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(orgId, from, to, STATUS_DRAFT)
                .stream().filter(cn -> !STATUS_CANCELLED.equals(cn.getStatus())).toList();

        // Fetch all relevant tax lines in one query
        Set<UUID> invoiceIds = invoices.stream().map(Invoice::getId).collect(Collectors.toSet());
        Set<UUID> cnIds = creditNotes.stream().map(CreditNote::getId).collect(Collectors.toSet());
        Set<UUID> allSourceIds = new HashSet<>();
        allSourceIds.addAll(invoiceIds);
        allSourceIds.addAll(cnIds);

        List<TaxLineItem> allTaxLines = allSourceIds.isEmpty()
                ? List.of()
                : taxLineItemRepository.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                        orgId, List.of("INVOICE", "CREDIT_NOTE"), GST_REGIME, allSourceIds);

        Map<UUID, List<TaxLineItem>> taxBySource = allTaxLines.stream()
                .collect(Collectors.groupingBy(TaxLineItem::getSourceId));

        // Pre-load contacts
        Set<UUID> contactIds = new HashSet<>();
        invoices.forEach(i -> contactIds.add(i.getContactId()));
        creditNotes.forEach(c -> contactIds.add(c.getContactId()));
        Map<UUID, Contact> contactMap = contactRepository.findAllById(contactIds).stream()
                .collect(Collectors.toMap(Contact::getId, c -> c));

        // Build sections
        List<Map<String, Object>> b2b = buildB2B(invoices, taxBySource, contactMap);
        List<Map<String, Object>> b2cs = buildB2CS(invoices, taxBySource, contactMap);
        List<Map<String, Object>> cdnr = buildCDNR(creditNotes, taxBySource, contactMap);
        List<Map<String, Object>> cdnur = buildCDNUR(creditNotes, taxBySource, contactMap);
        List<Map<String, Object>> hsn = buildHsnSummary(allTaxLines);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("gstin", orgGstin);
        result.put("fp", String.format("%02d%d", month, year));
        result.put("b2b", b2b);
        result.put("b2cs", b2cs);
        result.put("cdnr", cdnr);
        result.put("cdnur", cdnur);
        result.put("hsnsac", hsn);
        result.put("_meta", Map.of(
                "invoiceCount", invoices.size(),
                "creditNoteCount", creditNotes.size(),
                "b2bCount", b2b.size(),
                "b2csCount", b2cs.size()
        ));
        return result;
    }

    // B2B — registered customers (have GSTIN)
    private List<Map<String, Object>> buildB2B(
            List<Invoice> invoices,
            Map<UUID, List<TaxLineItem>> taxBySource,
            Map<UUID, Contact> contacts) {

        Map<String, List<Invoice>> byGstin = new LinkedHashMap<>();
        for (Invoice inv : invoices) {
            Contact c = contacts.get(inv.getContactId());
            if (c == null || isBlank(c.getGstin())) continue;
            byGstin.computeIfAbsent(c.getGstin(), k -> new ArrayList<>()).add(inv);
        }

        List<Map<String, Object>> records = new ArrayList<>();
        for (Map.Entry<String, List<Invoice>> entry : byGstin.entrySet()) {
            List<Map<String, Object>> invList = new ArrayList<>();
            for (Invoice inv : entry.getValue()) {
                List<TaxLineItem> tls = taxBySource.getOrDefault(inv.getId(), List.of());
                invList.add(Map.of(
                        "inum", inv.getInvoiceNumber(),
                        "idt", inv.getInvoiceDate().toString(),
                        "val", inv.getTotalAmount(),
                        "pos", nvl(inv.getPlaceOfSupply()),
                        "rchrg", inv.isReverseCharge() ? "Y" : "N",
                        "inv_typ", "R",
                        "itms", buildTaxRateItems(tls)
                ));
            }
            records.add(Map.of("ctin", entry.getKey(), "inv", invList));
        }
        return records;
    }

    // B2CS — unregistered / consumer customers, grouped by rate + state
    private List<Map<String, Object>> buildB2CS(
            List<Invoice> invoices,
            Map<UUID, List<TaxLineItem>> taxBySource,
            Map<UUID, Contact> contacts) {

        record Key(BigDecimal rate, String pos) {}
        Map<Key, BigDecimal[]> buckets = new LinkedHashMap<>();

        for (Invoice inv : invoices) {
            Contact c = contacts.get(inv.getContactId());
            if (c != null && !isBlank(c.getGstin())) continue; // skip B2B
            List<TaxLineItem> tls = taxBySource.getOrDefault(inv.getId(), List.of());
            String pos = nvl(inv.getPlaceOfSupply());

            Map<BigDecimal, List<TaxLineItem>> byRate = tls.stream()
                    .collect(Collectors.groupingBy(TaxLineItem::getRate));
            for (Map.Entry<BigDecimal, List<TaxLineItem>> re : byRate.entrySet()) {
                Key key = new Key(re.getKey(), pos);
                BigDecimal[] sums = buckets.computeIfAbsent(key, k -> new BigDecimal[]{
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
                for (TaxLineItem tl : re.getValue()) {
                    sums[0] = sums[0].add(tl.getTaxableAmount());
                    switch (tl.getComponentCode()) {
                        case "IGST" -> sums[1] = sums[1].add(tl.getTaxAmount());
                        case "CGST" -> sums[2] = sums[2].add(tl.getTaxAmount());
                        case "SGST" -> sums[3] = sums[3].add(tl.getTaxAmount());
                    }
                }
            }
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (Map.Entry<Key, BigDecimal[]> e : buckets.entrySet()) {
            BigDecimal[] s = e.getValue();
            String typ = s[1].compareTo(BigDecimal.ZERO) > 0 ? "INTER" : "INTRA";
            result.add(Map.of(
                    "sply_tp", typ,
                    "pos", e.getKey().pos(),
                    "rt", e.getKey().rate(),
                    "txval", s[0],
                    "iamt", s[1],
                    "camt", s[2],
                    "samt", s[3]
            ));
        }
        return result;
    }

    // CDNR — credit notes to registered customers
    private List<Map<String, Object>> buildCDNR(
            List<CreditNote> creditNotes,
            Map<UUID, List<TaxLineItem>> taxBySource,
            Map<UUID, Contact> contacts) {

        Map<String, List<CreditNote>> byGstin = new LinkedHashMap<>();
        for (CreditNote cn : creditNotes) {
            Contact c = contacts.get(cn.getContactId());
            if (c == null || isBlank(c.getGstin())) continue;
            byGstin.computeIfAbsent(c.getGstin(), k -> new ArrayList<>()).add(cn);
        }

        List<Map<String, Object>> records = new ArrayList<>();
        for (Map.Entry<String, List<CreditNote>> entry : byGstin.entrySet()) {
            List<Map<String, Object>> cnList = new ArrayList<>();
            for (CreditNote cn : entry.getValue()) {
                List<TaxLineItem> tls = taxBySource.getOrDefault(cn.getId(), List.of());
                cnList.add(Map.of(
                        "ntty", "C",
                        "nt_num", cn.getCreditNoteNumber(),
                        "nt_dt", cn.getCreditNoteDate().toString(),
                        "val", cn.getTotalAmount(),
                        "pos", nvl(cn.getPlaceOfSupply()),
                        "rchrg", "N",
                        "itms", buildTaxRateItems(tls)
                ));
            }
            records.add(Map.of("ctin", entry.getKey(), "nt", cnList));
        }
        return records;
    }

    // CDNUR — credit notes to unregistered customers
    private List<Map<String, Object>> buildCDNUR(
            List<CreditNote> creditNotes,
            Map<UUID, List<TaxLineItem>> taxBySource,
            Map<UUID, Contact> contacts) {

        List<Map<String, Object>> result = new ArrayList<>();
        for (CreditNote cn : creditNotes) {
            Contact c = contacts.get(cn.getContactId());
            if (c != null && !isBlank(c.getGstin())) continue; // skip registered
            List<TaxLineItem> tls = taxBySource.getOrDefault(cn.getId(), List.of());
            result.add(Map.of(
                    "ntty", "C",
                    "nt_num", cn.getCreditNoteNumber(),
                    "nt_dt", cn.getCreditNoteDate().toString(),
                    "val", cn.getTotalAmount(),
                    "pos", nvl(cn.getPlaceOfSupply()),
                    "typ", "B2CL",
                    "itms", buildTaxRateItems(tls)
            ));
        }
        return result;
    }

    // HSN/SAC summary — all tax lines grouped by HSN code
    private List<Map<String, Object>> buildHsnSummary(List<TaxLineItem> taxLines) {
        Map<String, BigDecimal[]> byHsn = new LinkedHashMap<>();
        for (TaxLineItem tl : taxLines) {
            String hsn = tl.getHsnCode() != null ? tl.getHsnCode() : "0000";
            BigDecimal[] s = byHsn.computeIfAbsent(hsn, k -> new BigDecimal[]{
                    BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO});
            s[0] = s[0].add(tl.getTaxableAmount());
            BigDecimal tax = tl.getTaxAmount();
            switch (tl.getComponentCode()) {
                case "IGST" -> s[1] = s[1].add(tax);
                case "CGST" -> s[2] = s[2].add(tax);
                case "SGST" -> s[3] = s[3].add(tax);
                case "CESS" -> s[4] = s[4].add(tax);
            }
        }

        List<Map<String, Object>> result = new ArrayList<>();
        for (Map.Entry<String, BigDecimal[]> e : byHsn.entrySet()) {
            BigDecimal[] s = e.getValue();
            BigDecimal totalTax = s[1].add(s[2]).add(s[3]).add(s[4]);
            result.add(Map.of(
                    "hsn_sc", e.getKey(),
                    "txval", s[0],
                    "iamt", s[1],
                    "camt", s[2],
                    "samt", s[3],
                    "csamt", s[4],
                    "tot_tx", totalTax
            ));
        }
        return result;
    }

    private List<Map<String, Object>> buildTaxRateItems(List<TaxLineItem> tls) {
        Map<BigDecimal, List<TaxLineItem>> byRate = tls.stream()
                .collect(Collectors.groupingBy(TaxLineItem::getRate));
        List<Map<String, Object>> items = new ArrayList<>();
        for (Map.Entry<BigDecimal, List<TaxLineItem>> re : byRate.entrySet()) {
            BigDecimal txval = BigDecimal.ZERO, cgst = BigDecimal.ZERO,
                    sgst = BigDecimal.ZERO, igst = BigDecimal.ZERO, cess = BigDecimal.ZERO;
            for (TaxLineItem tl : re.getValue()) {
                txval = txval.add(tl.getTaxableAmount());
                switch (tl.getComponentCode()) {
                    case "CGST" -> cgst = cgst.add(tl.getTaxAmount());
                    case "SGST" -> sgst = sgst.add(tl.getTaxAmount());
                    case "IGST" -> igst = igst.add(tl.getTaxAmount());
                    case "CESS" -> cess = cess.add(tl.getTaxAmount());
                }
            }
            items.add(Map.of(
                    "rt", re.getKey(),
                    "txval", txval,
                    "camt", cgst,
                    "samt", sgst,
                    "iamt", igst,
                    "csamt", cess
            ));
        }
        return items;
    }

    // ── GSTR-3B ──────────────────────────────────────────────────────

    /**
     * Full GSTR-3B with outward supplies, inward supplies, ITC, and net tax payable.
     */
    public Map<String, Object> generateGstr3b(int year, int month) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        String orgGstin = org != null && org.getGstin() != null ? org.getGstin() : "";

        LocalDate from = LocalDate.of(year, month, 1);
        LocalDate to = from.plusMonths(1).minusDays(1);

        // Outward — invoices
        List<Invoice> invoices = invoiceRepository.findPostedByOrgAndDateRange(orgId, from, to);
        Set<UUID> invoiceIds = invoices.stream().map(Invoice::getId).collect(Collectors.toSet());

        // Outward — credit notes (reduce output liability)
        List<CreditNote> creditNotes = creditNoteRepository
                .findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(orgId, from, to, STATUS_DRAFT)
                .stream().filter(cn -> !STATUS_CANCELLED.equals(cn.getStatus())).toList();
        Set<UUID> cnIds = creditNotes.stream().map(CreditNote::getId).collect(Collectors.toSet());

        // Inward — purchase bills (for ITC) — excludes DRAFT/CANCELLED/VOID
        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(orgId, from, to);
        Set<UUID> billIds = bills.stream().map(PurchaseBill::getId).collect(Collectors.toSet());

        // Fetch all tax lines in one batch
        Set<UUID> allIds = new HashSet<>();
        allIds.addAll(invoiceIds);
        allIds.addAll(cnIds);
        allIds.addAll(billIds);

        List<TaxLineItem> allLines = allIds.isEmpty() ? List.of()
                : taxLineItemRepository.findByOrgAndSourceTypesAndRegimeAndSourceIds(
                        orgId, List.of("INVOICE", "CREDIT_NOTE", "BILL"), GST_REGIME, allIds);

        List<TaxLineItem> outInvLines = allLines.stream()
                .filter(tl -> "INVOICE".equals(tl.getSourceType()) && invoiceIds.contains(tl.getSourceId()))
                .toList();
        List<TaxLineItem> outCnLines = allLines.stream()
                .filter(tl -> "CREDIT_NOTE".equals(tl.getSourceType()) && cnIds.contains(tl.getSourceId()))
                .toList();
        List<TaxLineItem> inwardLines = allLines.stream()
                .filter(tl -> "BILL".equals(tl.getSourceType()) && billIds.contains(tl.getSourceId()))
                .toList();

        // ── 3.1 Outward supplies ─────────────────────────────────────
        TaxSums outSales = sumTax(outInvLines);
        TaxSums outCn = sumTax(outCnLines);

        // Net outward (sales minus credit notes)
        BigDecimal netTaxable = outSales.taxable.subtract(outCn.taxable);
        BigDecimal netIgst = outSales.igst.subtract(outCn.igst);
        BigDecimal netCgst = outSales.cgst.subtract(outCn.cgst);
        BigDecimal netSgst = outSales.sgst.subtract(outCn.sgst);
        BigDecimal netCess = outSales.cess.subtract(outCn.cess);
        BigDecimal totalOutputTax = netIgst.add(netCgst).add(netSgst).add(netCess);

        // Count B2B vs B2CS
        Map<UUID, Contact> contactMap = loadContacts(invoices, creditNotes);
        long b2bCount = invoices.stream().filter(i -> {
            Contact c = contactMap.get(i.getContactId());
            return c != null && !isBlank(c.getGstin());
        }).count();

        Map<String, Object> outwardSupplies = new LinkedHashMap<>();
        outwardSupplies.put("osup_det", Map.of(
                "txval", netTaxable,
                "iamt", netIgst,
                "camt", netCgst,
                "samt", netSgst,
                "csamt", netCess
        ));

        // ── 4 ITC (Input Tax Credit) from purchase bills ─────────────
        TaxSums itc = sumTax(inwardLines);
        BigDecimal totalItc = itc.igst.add(itc.cgst).add(itc.sgst).add(itc.cess);

        Map<String, Object> itcSection = new LinkedHashMap<>();
        itcSection.put("itc_avl", List.of(
                Map.of("ty", "IMPG", "iamt", BigDecimal.ZERO, "camt", BigDecimal.ZERO,
                        "samt", BigDecimal.ZERO, "csamt", BigDecimal.ZERO),
                Map.of("ty", "IMPS", "iamt", BigDecimal.ZERO, "camt", BigDecimal.ZERO,
                        "samt", BigDecimal.ZERO, "csamt", BigDecimal.ZERO),
                Map.of("ty", "ISRC", "iamt", itc.igst, "camt", itc.cgst,
                        "samt", itc.sgst, "csamt", itc.cess)
        ));
        itcSection.put("itc_rev", List.of());
        itcSection.put("itc_net", Map.of(
                "iamt", itc.igst,
                "camt", itc.cgst,
                "samt", itc.sgst,
                "csamt", itc.cess
        ));
        itcSection.put("itc_inelg", List.of());

        // ── Net tax payable ───────────────────────────────────────────
        BigDecimal netPayable = totalOutputTax.subtract(totalItc).max(BigDecimal.ZERO);
        Map<String, Object> taxPayable = Map.of(
                "igst", netIgst.subtract(itc.igst).max(BigDecimal.ZERO),
                "cgst", netCgst.subtract(itc.cgst).max(BigDecimal.ZERO),
                "sgst", netSgst.subtract(itc.sgst).max(BigDecimal.ZERO),
                "cess", netCess.subtract(itc.cess).max(BigDecimal.ZERO),
                "total", netPayable
        );

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("gstin", orgGstin);
        result.put("fp", String.format("%02d%d", month, year));
        result.put("year", year);
        result.put("month", month);
        // Summary fields (for Flutter UI)
        result.put("totalInvoices", invoices.size());
        result.put("b2bInvoices", b2bCount);
        result.put("b2csInvoices", invoices.size() - b2bCount);
        result.put("creditNoteCount", creditNotes.size());
        result.put("billCount", bills.size());
        result.put("totalTaxable", netTaxable);
        result.put("totalIgst", netIgst);
        result.put("totalCgst", netCgst);
        result.put("totalSgst", netSgst);
        result.put("totalCess", netCess);
        result.put("totalTax", totalOutputTax);
        result.put("totalItcIgst", itc.igst);
        result.put("totalItcCgst", itc.cgst);
        result.put("totalItcSgst", itc.sgst);
        result.put("totalItcCess", itc.cess);
        result.put("totalItc", totalItc);
        result.put("netPayable", netPayable);
        // GSTN JSON sections
        result.put("sup_details", outwardSupplies);
        result.put("itc_elg", itcSection);
        result.put("inward_sup", Map.of("isup_details", List.of(
                Map.of("ty", "GST", "inter", itc.igst, "intra",
                        itc.cgst.add(itc.sgst))
        )));
        result.put("intr_ltfee", Map.of("intr_details", List.of()));
        result.put("tax_pay", taxPayable);
        return result;
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private record TaxSums(BigDecimal taxable, BigDecimal igst, BigDecimal cgst,
                           BigDecimal sgst, BigDecimal cess) {}

    private TaxSums sumTax(List<TaxLineItem> lines) {
        BigDecimal taxable = BigDecimal.ZERO, igst = BigDecimal.ZERO,
                cgst = BigDecimal.ZERO, sgst = BigDecimal.ZERO, cess = BigDecimal.ZERO;
        for (TaxLineItem tl : lines) {
            taxable = taxable.add(tl.getTaxableAmount());
            switch (tl.getComponentCode()) {
                case "IGST" -> igst = igst.add(tl.getTaxAmount());
                case "CGST" -> cgst = cgst.add(tl.getTaxAmount());
                case "SGST" -> sgst = sgst.add(tl.getTaxAmount());
                case "CESS" -> cess = cess.add(tl.getTaxAmount());
            }
        }
        return new TaxSums(taxable, igst, cgst, sgst, cess);
    }

    private Map<UUID, Contact> loadContacts(List<Invoice> invoices, List<CreditNote> cns) {
        Set<UUID> ids = new HashSet<>();
        invoices.forEach(i -> ids.add(i.getContactId()));
        cns.forEach(c -> ids.add(c.getContactId()));
        return contactRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Contact::getId, c -> c));
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private String nvl(String s) {
        return s != null ? s : "";
    }
}
