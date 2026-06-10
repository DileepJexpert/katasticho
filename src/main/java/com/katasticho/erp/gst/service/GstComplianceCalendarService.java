package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
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
    private final Clock clock;

    @Transactional(readOnly = true)
    public List<Map<String, Object>> calendar() {
        UUID orgId = requireOrgId();
        LocalDate today = LocalDate.now(clock);
        YearMonth lastMonth = YearMonth.from(today).minusMonths(1);

        List<Map<String, Object>> items = new ArrayList<>();

        items.add(item("GSTR1", "File GSTR-1 (outward supplies)", lastMonth,
                lastMonth.plusMonths(1).atDay(11), today,
                "Pre-built from posted invoices — export the JSON from the GST screen and file on the portal."));

        items.add(item("GSTR3B", "File GSTR-3B (summary return + tax payment)", lastMonth,
                lastMonth.plusMonths(1).atDay(20), today,
                "Pre-built with output tax and ITC — review net payable before filing."));

        items.add(item("TDS_DEPOSIT", "Deposit TDS deducted on vendor payments", lastMonth,
                lastMonth.plusMonths(1).atDay(7), today,
                "Deposit TDS for " + lastMonth + " via challan ITNS-281."));

        // 2B reconciliation nudge: the portal generates 2B on the 14th.
        LocalDate twoBDate = lastMonth.plusMonths(1).atDay(14);
        if (!today.isBefore(twoBDate)) {
            long uploaded = gstr2bEntryRepository.countByOrgIdAndReturnPeriod(orgId, lastMonth.toString());
            Map<String, Object> recon = item("GSTR2B_RECON", "Reconcile GSTR-2B (input credit)",
                    lastMonth, twoBDate.plusDays(6), today,
                    uploaded > 0
                            ? "2B uploaded (" + uploaded + " entries) — review mismatches in the AI Inbox."
                            : "Download GSTR-2B JSON from the portal and upload it here to match your purchase bills.");
            recon.put("done", uploaded > 0);
            items.add(recon);
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
