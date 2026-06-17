package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.dto.ItcRiskDtos.ItcRiskReport;
import com.katasticho.erp.gst.dto.ItcRiskDtos.SupplierRisk;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.TextStyle;
import java.util.*;

/**
 * ITC-at-risk monitor — the <em>preventive</em> half of GSTR-2B reconciliation.
 *
 * <p>Incumbent recon tools fetch 2B after it freezes (the 14th) and tell you what
 * input credit you already lost. By then a supplier who didn't file their GSTR-1
 * has already blocked your ITC for the cycle (Sec 16(2)(c)). This monitor runs in
 * the window <em>before</em> the cutoff: it compares your posted purchase bills
 * against the real-time GSTR-2A feed and, for every registered supplier whose
 * invoices haven't been reported yet, surfaces the ₹ of ITC at risk plus a
 * ready-to-forward WhatsApp nudge — so the owner can chase them before the lock.
 *
 * <p><b>Honest degradation:</b> with no filing signal yet (no 2A/2B fetched or
 * uploaded) it returns {@code dataAvailable=false} and flags nobody, rather than
 * crying wolf on every supplier.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ItcRiskMonitorService {

    static final String SUGGESTION_TYPE = "ITC_AT_RISK";
    private static final Set<String> OPEN_STATUSES = Set.of("PENDING", "DEFERRED");
    private static final BigDecimal HIGH_VALUE = new BigDecimal("10000");

    private final PurchaseBillRepository purchaseBillRepository;
    private final ContactRepository contactRepository;
    private final Gstr2bEntryRepository entryRepository;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final GspClient gspClient;
    private final Gstr2bReconService gstr2bReconService;
    private final com.katasticho.erp.gst.repository.GstFilingSnapshotRepository filingSnapshotRepository;
    private final java.time.Clock clock;

    // ── Assess (read) ─────────────────────────────────────────────────────

    /** Per-supplier ITC at risk for an invoice month, comparing books vs filed data. */
    @Transactional(readOnly = true)
    public ItcRiskReport assessRisk(String period) {
        UUID orgId = requireOrgId();
        YearMonth ym = parsePeriod(period);
        int daysToDeadline = daysToDeadline(ym);
        String urgency = urgency(daysToDeadline);

        var snapshot = filingSnapshotRepository.findByOrgIdAndReturnPeriod(orgId, ym.toString());
        String source = snapshot.map(s -> s.getSource()).orElse(null);
        java.time.Instant refreshedAt = snapshot.map(s -> s.getRefreshedAt()).orElse(null);

        // What suppliers have actually reported (from a 2A/2B fetch or upload).
        List<Gstr2bEntry> filed = entryRepository
                .findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, ym.toString());
        if (filed.isEmpty()) {
            return new ItcRiskReport(ym.toString(), false, BigDecimal.ZERO, 0, List.of(),
                    "No filing data yet for " + monthLabel(ym) + ". Connect a GSP to pull GSTR-2A, "
                            + "or upload it, so unfiled suppliers can be flagged before the cutoff.",
                    source, refreshedAt, daysToDeadline, urgency);
        }
        Set<String> filedKeys = new HashSet<>();
        for (Gstr2bEntry e : filed) {
            filedKeys.add(Gstr2bReconService.matchKey(e.getSupplierGstin(), e.getInvoiceNumber()));
        }

        List<PurchaseBill> bills = purchaseBillRepository
                .findPostedByOrgAndDateRange(orgId, ym.atDay(1), ym.atEndOfMonth());
        Map<UUID, Contact> vendors = loadVendors(orgId, bills);

        // Aggregate the unreported bills per supplier.
        Map<UUID, Agg> byVendor = new LinkedHashMap<>();
        for (PurchaseBill bill : bills) {
            Contact v = vendors.get(bill.getContactId());
            if (v == null || isBlank(v.getGstin()) || isBlank(bill.getVendorBillNumber())) {
                continue; // unregistered or no supplier invoice no. — no 2A row expected
            }
            String key = Gstr2bReconService.matchKey(v.getGstin(), bill.getVendorBillNumber());
            if (filedKeys.contains(key)) {
                continue; // supplier already reported it — safe
            }
            byVendor.computeIfAbsent(bill.getContactId(), k -> new Agg(v))
                    .add(bill.getVendorBillNumber(), nz(bill.getTaxAmount()));
        }

        List<SupplierRisk> risks = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Agg a : byVendor.values()) {
            String phone = firstNonBlank(a.vendor.getMobile(), a.vendor.getPhone());
            String msg = supplierMessage(a, ym);
            risks.add(new SupplierRisk(a.vendor.getId(), a.vendor.getDisplayName(), a.vendor.getGstin(),
                    phone, a.itc, a.invoiceNumbers.size(), List.copyOf(a.invoiceNumbers),
                    msg, whatsAppUrl(phone, msg)));
            total = total.add(a.itc);
        }
        risks.sort(Comparator.comparing(SupplierRisk::itcAtRisk).reversed());

        String message = risks.isEmpty()
                ? "All reported so far — no ITC at risk for " + monthLabel(ym) + " yet."
                : risks.size() + " supplier(s) haven't filed — ₹" + plain(total)
                        + " of ITC at risk for " + monthLabel(ym) + deadlinePhrase(daysToDeadline) + ".";
        return new ItcRiskReport(ym.toString(), true, total, risks.size(), risks, message,
                source, refreshedAt, daysToDeadline, urgency);
    }

    // ── Alert (write — Inbox suggestions only) ────────────────────────────

    /**
     * Best-effort refresh of the real-time 2A via the GSP, then raise alerts. The
     * scheduled monitor calls this; the fetch is skipped silently when no GSP is set.
     */
    @Transactional
    public int refreshAndAlert(String period) {
        UUID orgId = requireOrgId();
        YearMonth ym = parsePeriod(period);
        try {
            if (gspClient.isConfigured(orgId)) {
                String mmYYYY = String.format("%02d%04d", ym.getMonthValue(), ym.getYear());
                Map<String, Object> portal = gspClient.fetchGstr2a(orgId, mmYYYY);
                // Reuse the ingest path, stamped as the real-time 2A source.
                gstr2bReconService.upload(ym.toString(), portal, "GSTR_2A");
            }
        } catch (Exception e) {
            // GSP unreachable / nobody filed yet (GST_2B_EMPTY) — proceed on existing data.
            log.debug("ITC monitor 2A refresh skipped for org {} {}: {}", orgId, ym, e.getMessage());
        }
        return raiseAlerts(period);
    }

    /**
     * One ITC_AT_RISK suggestion per at-risk supplier — created if new, or
     * <b>escalated</b> in place on re-run as the filing deadline nears (priority
     * and reasoning are bumped, no duplicate is made). Returns how many were newly created.
     */
    @Transactional
    public int raiseAlerts(String period) {
        UUID orgId = requireOrgId();
        ItcRiskReport report = assessRisk(period);
        if (!report.dataAvailable()) {
            return 0;
        }
        int days = report.daysToDeadline();
        String urgency = report.urgency();
        int created = 0, escalated = 0;
        for (SupplierRisk r : report.suppliers()) {
            String priority = priorityFor(r.itcAtRisk(), urgency);
            BigDecimal score = scoreFor(r.itcAtRisk(), urgency);
            String reasoning = reasoning(r, report.period(), days);
            Map<String, Object> value = suggestedValue(r, report.period(), days, urgency);

            var existing = aiSuggestionRepository
                    .findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                            orgId, "CONTACT", r.contactId(), SUGGESTION_TYPE, OPEN_STATUSES);
            if (existing.isPresent()) {
                AiSuggestion s = existing.get();
                // Escalate in place — only bump, never downgrade an owner-seen alert.
                if (score.compareTo(nz(s.getPriorityScore())) > 0) {
                    s.setPriority(priority);
                    s.setPriorityScore(score);
                    s.setReasoning(reasoning);
                    s.setSuggestedValue(value);
                    aiSuggestionRepository.save(s);
                    escalated++;
                }
                continue;
            }
            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .orgId(orgId)
                    .entityType("CONTACT")
                    .entityId(r.contactId())
                    .suggestionType(SUGGESTION_TYPE)
                    .suggestedAction("NUDGE_SUPPLIER_TO_FILE")
                    .suggestedValue(value)
                    .reasoning(reasoning)
                    .confidence(new BigDecimal("0.950"))
                    .agentName("itc_risk_monitor")
                    .modelName("deterministic_rules")
                    .modelVersion("1")
                    .promptVersion("none")
                    .priority(priority)
                    .priorityScore(score)
                    .status("PENDING")
                    .build());
            created++;
        }
        log.info("ITC-at-risk monitor: {} new + {} escalated alert(s) for org {} period {} ({})",
                created, escalated, orgId, period, urgency);
        return created;
    }

    private Map<String, Object> suggestedValue(SupplierRisk r, String period, int days, String urgency) {
        Map<String, Object> value = new LinkedHashMap<>();
        value.put("period", period);
        value.put("supplierName", r.supplierName());
        value.put("gstin", r.gstin());
        value.put("phone", r.phone());
        value.put("itcAtRisk", plain(r.itcAtRisk()));
        value.put("invoiceCount", r.invoiceCount());
        value.put("invoiceNumbers", r.invoiceNumbers());
        value.put("draftMessage", r.draftMessage());
        value.put("daysToDeadline", days);
        value.put("urgency", urgency);
        if (r.whatsappUrl() != null && !r.whatsappUrl().isBlank()) {
            value.put("whatsappUrl", r.whatsappUrl());
        }
        return value;
    }

    private String reasoning(SupplierRisk r, String period, int days) {
        return r.supplierName() + " hasn't reported GSTR-1 for " + period + " — ₹"
                + plain(r.itcAtRisk()) + " of your ITC across " + r.invoiceCount()
                + " invoice(s) is at risk and will be blocked under Sec 16(2)(c)"
                + deadlinePhrase(days) + ". Forward the ready reminder to nudge them.";
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    // ── Deadline urgency (escalates as the 11th approaches) ───────────────

    /** GSTR-1 for invoice month P is due the 11th of P+1; days from today to that. */
    private int daysToDeadline(YearMonth period) {
        LocalDate today = LocalDate.now(clock);
        LocalDate deadline = period.plusMonths(1).atDay(11);
        return (int) java.time.temporal.ChronoUnit.DAYS.between(today, deadline);
    }

    private static String urgency(int days) {
        if (days < 0) return "OVERDUE";
        if (days <= 3) return "CRITICAL";
        if (days <= 7) return "URGENT";
        return "NORMAL";
    }

    private static String deadlinePhrase(int days) {
        if (days < 0) return " — the " + Math.abs(days) + "-day-old filing deadline has passed";
        if (days == 0) return " — the filing deadline is TODAY (11th)";
        return " if it isn't filed in the next " + days + " day(s) (deadline 11th)";
    }

    /** Amount sets the floor; nearness to the deadline bumps it (capped at 99). */
    private static BigDecimal scoreFor(BigDecimal itc, String urgency) {
        int base = itc.compareTo(HIGH_VALUE) >= 0 ? 70 : 50;
        int bonus = switch (urgency) {
            case "OVERDUE" -> 29;
            case "CRITICAL" -> 25;
            case "URGENT" -> 15;
            default -> 0;
        };
        return BigDecimal.valueOf(Math.min(99, base + bonus));
    }

    private static String priorityFor(BigDecimal itc, String urgency) {
        return scoreFor(itc, urgency).intValue() >= 75 ? "HIGH" : "MEDIUM";
    }

    private String supplierMessage(Agg a, YearMonth ym) {
        String nums = String.join(", ", a.invoiceNumbers);
        return "Dear " + a.vendor.getDisplayName() + ", our records show your GSTR-1 for "
                + monthLabel(ym) + " has not yet reported invoice(s) " + nums
                + " (tax ₹" + plain(a.itc) + "). Please file before the 11th so we can claim "
                + "the input tax credit. Thank you.";
    }

    private static String whatsAppUrl(String phone, String message) {
        if (phone == null || phone.isBlank()) return "";
        String clean = phone.replaceAll("[\\s\\-+]", "");
        if (clean.length() == 10) clean = "91" + clean;
        return "https://wa.me/" + clean + "?text=" + URLEncoder.encode(message, StandardCharsets.UTF_8);
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
            throw new BusinessException("Period must be YYYY-MM, e.g. 2026-05", "ITC_BAD_PERIOD");
        }
    }

    private static String monthLabel(YearMonth ym) {
        return ym.getMonth().getDisplayName(TextStyle.SHORT, Locale.ENGLISH) + " " + ym.getYear();
    }

    private static String plain(BigDecimal v) {
        return (v == null ? BigDecimal.ZERO : v).stripTrailingZeros().toPlainString();
    }

    private static String firstNonBlank(String... vals) {
        for (String v : vals) if (v != null && !v.isBlank()) return v.trim();
        return null;
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

    /** Mutable per-supplier accumulator. */
    private static final class Agg {
        final Contact vendor;
        BigDecimal itc = BigDecimal.ZERO;
        final List<String> invoiceNumbers = new ArrayList<>();
        Agg(Contact vendor) { this.vendor = vendor; }
        void add(String invoiceNumber, BigDecimal tax) {
            invoiceNumbers.add(invoiceNumber);
            itc = itc.add(tax);
        }
    }
}
