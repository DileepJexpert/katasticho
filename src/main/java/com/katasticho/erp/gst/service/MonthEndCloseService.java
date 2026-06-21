package com.katasticho.erp.gst.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * One-click month-end close pack. Aggregates readiness signals into a
 * checklist with statuses + the single biggest blockers so the user can
 * see whether the books are ready to file before they hit "Generate 3B".
 *
 * <p>Per the strategy doc this is the surface the conversational close
 * agent calls — also reachable directly so a user can drive it without
 * the chat.
 *
 * <p>Each item has a status of READY / NEEDS_ATTENTION / BLOCKED and a
 * human-readable summary. The overall {@code closable} flag is true only
 * when no item is BLOCKED.
 */
@Service
@RequiredArgsConstructor
public class MonthEndCloseService {

    private final ImsService imsService;
    private final Gst20RateRemapper rateRemapper;
    private final FiscalPeriodRepository fiscalPeriodRepository;

    public record ChecklistItem(
            String id,
            String title,
            String status,        // READY | NEEDS_ATTENTION | BLOCKED
            String summary,
            Object detail
    ) {}

    @Transactional(readOnly = true)
    public Map<String, Object> checklist(int year, int month) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String period = String.format("%04d-%02d", year, month);

        List<ChecklistItem> items = new ArrayList<>();
        items.add(fiscalPeriodItem(orgId, year, month));
        items.add(imsActionItem(period));
        items.add(reconMismatchItem(period));
        items.add(gst20RemapItem());
        items.add(gstr1ReadyItem(period));
        items.add(gstr3bReadyItem(period));

        // Roll-up
        boolean blocked = items.stream().anyMatch(i -> "BLOCKED".equals(i.status));
        boolean needsAttention = items.stream().anyMatch(i -> "NEEDS_ATTENTION".equals(i.status));
        String overall = blocked ? "BLOCKED" : (needsAttention ? "NEEDS_ATTENTION" : "READY");

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("period", period);
        out.put("overallStatus", overall);
        out.put("closable", !blocked);
        out.put("items", items);
        return out;
    }

    // ── item builders ────────────────────────────────────────────

    /** Fiscal period must be OPEN (else we already closed). */
    ChecklistItem fiscalPeriodItem(UUID orgId, int year, int month) {
        Optional<FiscalPeriod> fp = fiscalPeriodRepository
                .findByOrgIdAndPeriodYearAndPeriodMonth(orgId, year, month);
        if (fp.isEmpty()) {
            return new ChecklistItem("fiscal-period",
                    "Fiscal period",
                    "READY",
                    "Period " + year + "-" + month + " is not tracked — nothing to gate.",
                    null);
        }
        String status = fp.get().getStatus();
        if ("CLOSED".equals(status)) {
            return new ChecklistItem("fiscal-period",
                    "Fiscal period",
                    "READY",
                    "Already closed.",
                    Map.of("status", status));
        }
        return new ChecklistItem("fiscal-period",
                "Fiscal period",
                "NEEDS_ATTENTION",
                "Period is OPEN — closing it after filing locks back-dated entries.",
                Map.of("status", status));
    }

    /** IMS: no-action rows = deemed-accepted ITC exposure = BLOCKED until reviewed. */
    ChecklistItem imsActionItem(String period) {
        Map<String, Object> summary = imsService.periodSummary(period);
        long noAction = ((Number) summary.getOrDefault("noAction", 0L)).longValue();
        long total = ((Number) summary.getOrDefault("totalRows", 0L)).longValue();
        BigDecimal exposure = (BigDecimal) summary
                .getOrDefault("deemedAcceptedItcExposure", BigDecimal.ZERO);

        if (total == 0) {
            return new ChecklistItem("ims",
                    "IMS actions",
                    "READY",
                    "No GSTR-2B rows uploaded for this period yet.",
                    summary);
        }
        if (noAction == 0) {
            return new ChecklistItem("ims",
                    "IMS actions",
                    "READY",
                    "All " + total + " rows actioned (accepted / rejected / pending).",
                    summary);
        }
        return new ChecklistItem("ims",
                "IMS actions",
                "BLOCKED",
                noAction + " of " + total + " rows still need an action. "
                        + "Deemed-accepted ITC exposure: ₹" + exposure + ".",
                summary);
    }

    ChecklistItem reconMismatchItem(String period) {
        Map<String, Object> imsSummary = imsService.periodSummary(period);
        long rejected = ((Number) imsSummary.getOrDefault("rejected", 0L)).longValue();
        long pending = ((Number) imsSummary.getOrDefault("pending", 0L)).longValue();
        long flagged = rejected + pending;
        if (flagged == 0) {
            return new ChecklistItem("2b-recon",
                    "2B reconciliation",
                    "READY",
                    "No rejected or pending rows — every match is clean.",
                    Map.of("rejected", rejected, "pending", pending));
        }
        return new ChecklistItem("2b-recon",
                "2B reconciliation",
                "NEEDS_ATTENTION",
                flagged + " row(s) need supplier follow-up (rejected/pending). "
                        + "These hold up ITC.",
                Map.of("rejected", rejected, "pending", pending));
    }

    ChecklistItem gst20RemapItem() {
        Map<String, Object> cands = rateRemapper.candidates();
        int total = ((Number) cands.getOrDefault("totalDriftItems", 0)).intValue();
        if (total == 0) {
            return new ChecklistItem("gst-20-remap",
                    "GST 2.0 rate alignment",
                    "READY",
                    "All items match the post-9/2025 HSN master rates.",
                    cands);
        }
        return new ChecklistItem("gst-20-remap",
                "GST 2.0 rate alignment",
                "NEEDS_ATTENTION",
                total + " item(s) carry stale GST rates. "
                        + "Filing at the old rate is a notice waiting to happen.",
                cands);
    }

    /** GSTR-1 readiness is a thin signal here — full prep happens in GstService. */
    ChecklistItem gstr1ReadyItem(String period) {
        return new ChecklistItem("gstr-1",
                "GSTR-1 prep",
                "READY",
                "Sales side will auto-populate from posted invoices at /api/v1/gst/gstr1?period=" + period + ".",
                null);
    }

    /** 3B readiness gates on IMS being clean (auto-populated 2B drives 3B 4A1 ITC). */
    ChecklistItem gstr3bReadyItem(String period) {
        Map<String, Object> imsSummary = imsService.periodSummary(period);
        long noAction = ((Number) imsSummary.getOrDefault("noAction", 0L)).longValue();
        if (noAction > 0) {
            return new ChecklistItem("gstr-3b",
                    "GSTR-3B prep",
                    "BLOCKED",
                    "Cannot finalise 3B while " + noAction + " IMS row(s) are unactioned — "
                            + "the auto-populated ITC line would change after cutoff.",
                    null);
        }
        return new ChecklistItem("gstr-3b",
                "GSTR-3B prep",
                "READY",
                "Hit /api/v1/gst/gstr3b?period=" + period + " to render. "
                        + "Note: outward fields (3.1/3.2) are hard-locked from July 2025 — "
                        + "use GSTR-1A to correct.",
                null);
    }

    /** Compatibility wrapper if anyone wants today's month directly. */
    @Transactional(readOnly = true)
    public Map<String, Object> currentMonthChecklist() {
        LocalDate today = LocalDate.now();
        return checklist(today.getYear(), today.getMonthValue());
    }
}
