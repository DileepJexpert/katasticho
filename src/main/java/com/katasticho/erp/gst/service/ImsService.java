package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.gst.entity.Gstr2bEntry;
import com.katasticho.erp.gst.repository.Gstr2bEntryRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * GST Invoice Management System (IMS) action loop. Under amended Section 38
 * of the CGST Act (effective 1 Oct 2025), the recipient must Accept / Reject /
 * keep Pending every inward invoice that lands in IMS on the portal —
 * unactioned rows are silently "deemed accepted" into GSTR-2B at portal
 * cutoff, so missing this loop is real ITC exposure.
 *
 * <p>This service:
 * <ul>
 *   <li>Records buyer actions on existing {@link Gstr2bEntry} rows (already
 *       populated via {@link Gstr2bReconService#upload} or GSP fetch).</li>
 *   <li>Produces an AI recommendation per row from the existing {@code matchStatus}
 *       (MATCHED → ACCEPT, VALUE_MISMATCH → REJECT, NOT_IN_BOOKS → PENDING) so
 *       the cashier-grade reviewer just clicks through.</li>
 *   <li>Summarises the period: actioned, no-action (deemed-accepted risk),
 *       rejected, pending — drives the "Close June" checklist in
 *       {@link com.katasticho.erp.ai.service.ProactiveAgentService}.</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ImsService {

    public static final String ACCEPT = "ACCEPT";
    public static final String REJECT = "REJECT";
    public static final String PENDING = "PENDING";

    private final Gstr2bEntryRepository entryRepository;

    // ── Action loop ──────────────────────────────────────────────

    @Transactional
    public Gstr2bEntry action(UUID entryId, String imsAction, String remarks) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        validateAction(imsAction);

        Gstr2bEntry e = entryRepository.findByIdAndOrgId(entryId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Gstr2bEntry", entryId));

        e.setImsAction(imsAction);
        e.setImsActionAt(Instant.now());
        e.setImsActionBy(userId);
        e.setImsRemarks(remarks);
        return entryRepository.save(e);
    }

    @Transactional
    public Map<String, Object> bulkAction(List<UUID> entryIds, String imsAction, String remarks) {
        validateAction(imsAction);
        if (entryIds == null || entryIds.isEmpty()) {
            throw new BusinessException(
                    "entryIds must not be empty", "IMS_NO_ROWS_SELECTED",
                    HttpStatus.BAD_REQUEST);
        }
        int ok = 0, skipped = 0;
        for (UUID id : entryIds) {
            try {
                action(id, imsAction, remarks);
                ok++;
            } catch (BusinessException ex) {
                log.warn("IMS bulk: skipping {} — {}", id, ex.getMessage());
                skipped++;
            }
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("ok", ok);
        out.put("skipped", skipped);
        out.put("action", imsAction);
        return out;
    }

    /** Apply the AI recommendation in bulk (one tap on every row that has a suggestion). */
    @Transactional
    public Map<String, Object> applyAllAiRecommendations(String returnPeriod) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        var rows = entryRepository
                .findByOrgIdAndReturnPeriodAndImsActionIsNullOrderBySupplierGstinAsc(orgId, returnPeriod);

        int applied = 0, skippedNoRec = 0;
        for (Gstr2bEntry e : rows) {
            if (e.getImsAiRecommendation() == null) { skippedNoRec++; continue; }
            e.setImsAction(e.getImsAiRecommendation());
            e.setImsActionAt(Instant.now());
            e.setImsActionBy(userId);
            e.setImsRemarks(e.getImsAiReason());
            entryRepository.save(e);
            applied++;
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("applied", applied);
        out.put("skippedNoRecommendation", skippedNoRec);
        out.put("period", returnPeriod);
        return out;
    }

    // ── AI recommendations ───────────────────────────────────────

    /**
     * Compute and store an AI recommendation for every entry in the period
     * that doesn't already have one. The recommendation comes from the
     * existing {@code matchStatus}, which the recon service has already
     * stamped — so this is rule-based (deterministic, audit-trail-friendly)
     * rather than an LLM call.
     */
    @Transactional
    public Map<String, Object> recommendForPeriod(String returnPeriod) {
        UUID orgId = TenantContext.getCurrentOrgId();
        var rows = entryRepository
                .findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(orgId, returnPeriod);

        int accepted = 0, rejected = 0, pending = 0, alreadySet = 0;
        for (Gstr2bEntry e : rows) {
            if (e.getImsAction() != null) continue; // human already acted
            if (e.getImsAiRecommendation() != null) { alreadySet++; continue; }
            Recommendation r = recommendOne(e);
            e.setImsAiRecommendation(r.action);
            e.setImsAiReason(r.reason);
            entryRepository.save(e);
            switch (r.action) {
                case ACCEPT -> accepted++;
                case REJECT -> rejected++;
                case PENDING -> pending++;
            }
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("acceptedRecommendations", accepted);
        out.put("rejectedRecommendations", rejected);
        out.put("pendingRecommendations", pending);
        out.put("alreadyRecommended", alreadySet);
        out.put("period", returnPeriod);
        return out;
    }

    record Recommendation(String action, String reason) {}

    /**
     * Rule-based recommendation from {@code matchStatus}:
     * <ul>
     *   <li>MATCHED → ACCEPT — supplier invoice and our posted bill agree, ITC is safe.</li>
     *   <li>VALUE_MISMATCH → REJECT — taxable / tax amounts differ from our books;
     *       rejecting forces the supplier to revise (otherwise we under/over-claim ITC).</li>
     *   <li>NOT_IN_BOOKS → PENDING — no posted bill yet; we should draft one and
     *       keep the row pending until the bill exists.</li>
     *   <li>anything else (UNMATCHED) → PENDING — needs human review.</li>
     * </ul>
     */
    Recommendation recommendOne(Gstr2bEntry e) {
        String status = e.getMatchStatus() == null ? "UNMATCHED" : e.getMatchStatus();
        return switch (status) {
            case "MATCHED" -> new Recommendation(ACCEPT,
                    "Posted purchase bill matches supplier invoice on GSTIN, invoice number, and value within tolerance.");
            case "VALUE_MISMATCH" -> new Recommendation(REJECT,
                    "Taxable / tax values in 2B differ from the posted bill. Reject to force supplier revision; "
                            + "accepting would lock in an incorrect ITC.");
            case "NOT_IN_BOOKS" -> new Recommendation(PENDING,
                    "No purchase bill posted against this supplier invoice yet. Keep pending and draft the bill — "
                            + "deemed-accepted ITC without a bill is a notice waiting to happen.");
            default -> new Recommendation(PENDING,
                    "Match status is " + status + " — needs human review before acceptance.");
        };
    }

    // ── Period summary ───────────────────────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> periodSummary(String returnPeriod) {
        UUID orgId = TenantContext.getCurrentOrgId();
        long total = entryRepository.countByOrgIdAndReturnPeriod(orgId, returnPeriod);
        long noAction = entryRepository
                .countByOrgIdAndReturnPeriodAndImsActionIsNull(orgId, returnPeriod);
        long accepted = entryRepository
                .countByOrgIdAndReturnPeriodAndImsAction(orgId, returnPeriod, ACCEPT);
        long rejected = entryRepository
                .countByOrgIdAndReturnPeriodAndImsAction(orgId, returnPeriod, REJECT);
        long pending = entryRepository
                .countByOrgIdAndReturnPeriodAndImsAction(orgId, returnPeriod, PENDING);

        // Quantify the deemed-accepted ITC exposure.
        var noActionRows = entryRepository
                .findByOrgIdAndReturnPeriodAndImsActionIsNullOrderBySupplierGstinAsc(orgId, returnPeriod);
        BigDecimal exposedItc = BigDecimal.ZERO;
        for (Gstr2bEntry r : noActionRows) {
            exposedItc = exposedItc.add(r.totalTax());
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("period", returnPeriod);
        out.put("totalRows", total);
        out.put("noAction", noAction);
        out.put("accepted", accepted);
        out.put("rejected", rejected);
        out.put("pending", pending);
        out.put("deemedAcceptedItcExposure", exposedItc);
        if (noAction > 0) {
            out.put("warning",
                    noAction + " row(s) have no IMS action — they will be deemed accepted at portal cutoff. "
                            + "ITC of ₹" + exposedItc + " is silently locked in.");
        }
        return out;
    }

    @Transactional(readOnly = true)
    public List<Gstr2bEntry> noActionRows(String returnPeriod) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return entryRepository.findByOrgIdAndReturnPeriodAndImsActionIsNullOrderBySupplierGstinAsc(
                orgId, returnPeriod);
    }

    private static void validateAction(String action) {
        if (action == null) {
            throw new BusinessException(
                    "ims_action is required", "IMS_ACTION_REQUIRED",
                    HttpStatus.BAD_REQUEST);
        }
        switch (action) {
            case ACCEPT, REJECT, PENDING -> {}
            default -> throw new BusinessException(
                    "ims_action must be ACCEPT, REJECT, or PENDING (got '" + action + "')",
                    "IMS_INVALID_ACTION", HttpStatus.BAD_REQUEST);
        }
    }
}
