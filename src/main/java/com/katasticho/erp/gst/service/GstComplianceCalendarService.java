package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.gst.repository.EInvoiceRepository;
import com.katasticho.erp.gst.repository.EwayBillRepository;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * The proactive compliance surface: what is due, when, and whether the
 * artifact is ready — so the system tells the owner before the deadline
 * instead of the owner remembering it.
 *
 * Standard Indian SMB deadlines covered:
 *   GSTR-1  — 11th of the following month
 *   GSTR-3B — 20th of the following month
 *   TDS deposit — 7th of the following month
 *   GSTR-2B reconciliation — 2B lands on the 14th; nudge after that
 * Plus live items: pending e-way bills.
 */
@Service
@RequiredArgsConstructor
public class GstComplianceCalendarService {

    private static final int DUE_SOON_DAYS = 5;

    private final EwayBillRepository ewayBillRepository;
    private final Gstr2bEntryRepository gstr2bEntryRepository;
    private final EInvoiceRepository eInvoiceRepository;
    private final CompositionService compositionService;
    private final Clock clock;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> calendar() {
        UUID orgId = requireOrgId();
        LocalDate today = LocalDate.now(clock);
        YearMonth lastMonth = YearMonth.from(today).minusMonths(1);
        boolean composition = compositionService.isEnabled(orgId);

        List<Map<String, Object>> items = new ArrayList<>();

        if (composition) {
            // Composition dealers file quarterly CMP-08 + annual GSTR-4 instead
            // of monthly GSTR-1/3B, and have no ITC — so no 2B recon either.
            items.add(cmp08Item(today));
            items.add(gstr4Item(today));
        } else {
            items.add(item("GSTR1", "File GSTR-1 (outward supplies)", lastMonth,
                    lastMonth.plusMonths(1).atDay(11), today,
                    "Pre-built from posted invoices — export the JSON from the GST screen and file on the portal."));

            items.add(item("GSTR3B", "File GSTR-3B (summary return + tax payment)", lastMonth,
                    lastMonth.plusMonths(1).atDay(20), today,
                    "Pre-built with output tax and ITC — review net payable before filing."));
        }

        items.add(item("TDS_DEPOSIT", "Deposit TDS deducted on vendor payments", lastMonth,
                lastMonth.plusMonths(1).atDay(7), today,
                "Deposit TDS for " + lastMonth + " via challan ITNS-281."));

        // Form 26Q for the most recently ended quarter (Q1→Jul 31, Q2→Oct 31,
        // Q3→Jan 31, Q4→May 31).
        items.add(form26qItem(today));

        // 2B reconciliation nudge: the portal generates 2B on the 14th.
        LocalDate twoBDate = lastMonth.plusMonths(1).atDay(14);
        if (!composition && !today.isBefore(twoBDate)) {
            long uploaded = gstr2bEntryRepository.countByOrgIdAndReturnPeriod(orgId, lastMonth.toString());
            Map<String, Object> recon = item("GSTR2B_RECON", "Reconcile GSTR-2B (input credit)",
                    lastMonth, twoBDate.plusDays(6), today,
                    uploaded > 0
                            ? "2B uploaded (" + uploaded + " entries) — review mismatches in the AI Inbox."
                            : "Download GSTR-2B JSON from the portal and upload it here to match your purchase bills.");
            recon.put("done", uploaded > 0);
            items.add(recon);
        }

        long pendingEinv = eInvoiceRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING");
        if (pendingEinv > 0) {
            Map<String, Object> einv = new LinkedHashMap<>();
            einv.put("code", "EINVOICE_PENDING");
            einv.put("title", pendingEinv + " e-invoice(s) pending — IRN required for B2B validity");
            einv.put("period", YearMonth.from(today).toString());
            einv.put("dueDate", today);
            einv.put("daysLeft", 0);
            einv.put("status", "OVERDUE");
            einv.put("description",
                    "Generate the IRN on the IRP (the INV-01 JSON is prepared per invoice) and record it back.");
            items.add(einv);
        }

        long pendingEwb = ewayBillRepository.countByOrgIdAndStatusAndIsDeletedFalse(orgId, "PENDING");
        if (pendingEwb > 0) {
            Map<String, Object> ewb = new LinkedHashMap<>();
            ewb.put("code", "EWAY_PENDING");
            ewb.put("title", pendingEwb + " e-way bill(s) pending — required before goods move");
            ewb.put("period", YearMonth.from(today).toString());
            ewb.put("dueDate", today);
            ewb.put("daysLeft", 0);
            ewb.put("status", "OVERDUE");
            ewb.put("description",
                    "Generate on the NIC portal (JSON is prepared per document) and record the EWB numbers.");
            items.add(ewb);
        }

        return items;
    }

    /** CMP-08 for the most recently ended quarter, due the 18th of the next month. */
    private Map<String, Object> cmp08Item(LocalDate today) {
        // Quarter that ended most recently (calendar quarters aligned to FY).
        int month = today.getMonthValue();
        LocalDate quarterEnd = switch ((month - 1) / 3) {
            case 0 -> LocalDate.of(today.getYear() - 1, 12, 31);   // Jan–Mar → Oct–Dec ended
            case 1 -> LocalDate.of(today.getYear(), 3, 31);        // Apr–Jun → Jan–Mar ended
            case 2 -> LocalDate.of(today.getYear(), 6, 30);        // Jul–Sep → Apr–Jun ended
            default -> LocalDate.of(today.getYear(), 9, 30);       // Oct–Dec → Jul–Sep ended
        };
        LocalDate dueDate = quarterEnd.plusMonths(1).withDayOfMonth(18);
        Map<String, Object> m = item("CMP08",
                "File CMP-08 (composition quarterly statement)",
                YearMonth.from(quarterEnd), dueDate, today,
                "Flat-rate tax on the quarter's turnover — amounts are prepared under GST → Composition.");
        m.put("period", "Quarter ending " + quarterEnd);
        return m;
    }

    /** Annual GSTR-4 for composition dealers, due 30 April after the FY ends. */
    private Map<String, Object> gstr4Item(LocalDate today) {
        int fyEndYear = today.getMonthValue() >= 4 ? today.getYear() : today.getYear() - 1;
        LocalDate dueDate = LocalDate.of(fyEndYear, 4, 30);
        String fy = (fyEndYear - 1) + "-" + (fyEndYear % 100);
        return item("GSTR4", "File GSTR-4 (composition annual return) for FY " + fy,
                YearMonth.of(fyEndYear, 4), dueDate, today,
                "Annual summary for composition dealers — due 30 April after the FY.");
    }

    /** Form 26Q for the most recently ended quarter. FY quarters: Q1 Apr–Jun … Q4 Jan–Mar. */
    private Map<String, Object> form26qItem(LocalDate today) {
        int month = today.getMonthValue();
        int quarter;          // the quarter that just ended
        int fyStartYear;      // FY the quarter belongs to
        LocalDate dueDate;
        if (month >= 7 && month <= 9) {            // Q1 (Apr–Jun) ended
            quarter = 1; fyStartYear = today.getYear();
            dueDate = LocalDate.of(today.getYear(), 7, 31);
        } else if (month >= 10 && month <= 12) {   // Q2 ended
            quarter = 2; fyStartYear = today.getYear();
            dueDate = LocalDate.of(today.getYear(), 10, 31);
        } else if (month >= 1 && month <= 3) {     // Q3 ended (Oct–Dec of prev year)
            quarter = 3; fyStartYear = today.getYear() - 1;
            dueDate = LocalDate.of(today.getYear(), 1, 31);
        } else {                                   // Apr–Jun: Q4 (Jan–Mar) ended
            quarter = 4; fyStartYear = today.getYear() - 1;
            dueDate = LocalDate.of(today.getYear(), 5, 31);
        }
        String fy = fyStartYear + "-" + ((fyStartYear + 1) % 100);
        Map<String, Object> m = item("TDS_RETURN_26Q",
                "File Form 26Q (TDS return) for Q" + quarter + " FY " + fy,
                YearMonth.from(dueDate), dueDate, today,
                "Deductee-wise data is prepared under TDS → Form 26Q.");
        m.put("period", "Q" + quarter + " " + fy);
        return m;
    }

    private Map<String, Object> item(String code, String title, YearMonth period,
                                     LocalDate dueDate, LocalDate today, String description) {
        long daysLeft = ChronoUnit.DAYS.between(today, dueDate);
        String status = daysLeft < 0 ? "OVERDUE" : (daysLeft <= DUE_SOON_DAYS ? "DUE_SOON" : "UPCOMING");
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("code", code);
        m.put("title", title);
        m.put("period", period.toString());
        m.put("dueDate", dueDate);
        m.put("daysLeft", daysLeft);
        m.put("status", status);
        m.put("description", description);
        return m;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
