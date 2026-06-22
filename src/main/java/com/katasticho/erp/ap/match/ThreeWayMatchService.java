package com.katasticho.erp.ap.match;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.StockReceiptLineRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 3-way match: PO ↔ GRN ↔ Bill. Catches over-billing, qty-over-receipt, price
 * hikes, and amount mismatches BEFORE vendor payment.
 *
 * <p>Driven entirely by the V7 FKs — no name / amount heuristics. Per-line
 * decision tree:
 *
 * <ol>
 *   <li><b>SERVICE item</b> — skip GRN check (services don't receive into stock).
 *       Compare price only when PO line linked; else NO_PO.</li>
 *   <li><b>No purchaseOrderLineId</b> — NO_PO (unless bill total below
 *       {@code ap.three_way_match.bypass_threshold} → BYPASSED).</li>
 *   <li><b>PO linked, no GRN line referencing the same PO line</b> — NO_GRN.</li>
 *   <li><b>billedQty &gt; sumReceived × (1 + qtyTolerancePct/100)</b> — QTY_OVER.</li>
 *   <li><b>|billUnitPrice − poUnitPrice| &gt; max(priceToleranceAbs,
 *       poUnitPrice × priceTolerancePct)</b> — PRICE_HIKE.</li>
 *   <li>Else → MATCHED.</li>
 * </ol>
 *
 * <p>Overall bill status = MATCHED iff every line MATCHED; any non-MATCHED line
 * (other than BYPASSED) → EXCEPTION; all lines BYPASSED → BYPASSED.
 *
 * <p>On EXCEPTION, one {@code THREE_WAY_MATCH_EXCEPTION} HIGH-priority
 * {@link AiSuggestion} is drafted per bill (idempotent via
 * {@code existsOpenSuggestion}).
 *
 * <p>Tolerances (org settings, all under {@code ap.three_way_match.*}):
 * <ul>
 *   <li>{@code required} — {@code true} default. When false, match runs but
 *       EXCEPTION never blocks (still surfaces in inbox).</li>
 *   <li>{@code qty_tolerance_pct} — 0 default (zero qty over-receipt tolerated).</li>
 *   <li>{@code price_tolerance_abs} — ₹1 default.</li>
 *   <li>{@code price_tolerance_pct} — 0.5% default.</li>
 *   <li>{@code bypass_threshold} — 0 default (no bypass).</li>
 * </ul>
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ThreeWayMatchService {

    public static final String STATUS_MATCHED = "MATCHED";
    public static final String STATUS_EXCEPTION = "EXCEPTION";
    public static final String STATUS_BYPASSED = "BYPASSED";
    public static final String STATUS_OVERRIDDEN = "OVERRIDDEN";

    public static final String LINE_MATCHED = "MATCHED";
    public static final String LINE_QTY_OVER = "QTY_OVER";
    public static final String LINE_PRICE_HIKE = "PRICE_HIKE";
    public static final String LINE_AMOUNT_MISMATCH = "AMOUNT_MISMATCH";
    public static final String LINE_NO_PO = "NO_PO";
    public static final String LINE_NO_GRN = "NO_GRN";
    public static final String LINE_BYPASSED = "BYPASSED";

    public static final String SUGGESTION_TYPE = "THREE_WAY_MATCH_EXCEPTION";
    public static final String ENTITY_TYPE = "PURCHASE_BILL";

    private static final List<String> OPEN_STATUSES =
            List.of("PENDING", "IN_PROGRESS");

    private final PurchaseBillRepository billRepository;
    private final BillMatchResultLineRepository matchResultRepository;
    private final PurchaseOrderLineRepository purchaseOrderLineRepository;
    private final StockReceiptLineRepository stockReceiptLineRepository;
    private final ItemRepository itemRepository;
    private final OrgSettingsService orgSettingsService;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;

    /** Run match for a bill — replace-style. Returns the overall status. */
    @Transactional
    public String match(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));

        Tolerances tol = loadTolerances(orgId);

        // Replace-style: blow away prior result rows.
        matchResultRepository.deleteByOrgIdAndBillId(orgId, billId);

        List<BillMatchResultLine> results = new ArrayList<>();
        for (PurchaseBillLine line : bill.getLines()) {
            results.add(matchLine(bill, line, orgId, tol));
        }
        matchResultRepository.saveAll(results);

        String overall = computeOverallStatus(results, bill, tol);
        // Preserve OVERRIDDEN if the bill was already overridden — don't re-flip it
        // on every match run.
        if (!STATUS_OVERRIDDEN.equals(bill.getThreeWayMatchStatus())) {
            bill.setThreeWayMatchStatus(overall);
            bill.setThreeWayMatchAt(Instant.now());
            billRepository.save(bill);
        }

        if (STATUS_EXCEPTION.equals(overall)) {
            createSuggestionIfAbsent(bill, results);
        }

        log.info("3-way match bill {}: overall={} ({} lines)",
                bill.getBillNumber(), overall, results.size());
        return overall;
    }

    /** Manual OWNER/ADMIN override — locks the match status to OVERRIDDEN with reason. */
    @Transactional
    public void override(UUID billId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));

        if (STATUS_OVERRIDDEN.equals(bill.getThreeWayMatchStatus())) {
            throw new BusinessException("Bill match was already overridden",
                    "THREE_WAY_MATCH_ALREADY_OVERRIDDEN", HttpStatus.BAD_REQUEST);
        }
        if (reason == null || reason.isBlank()) {
            throw new BusinessException("Override reason required",
                    "THREE_WAY_MATCH_OVERRIDE_REASON_REQUIRED", HttpStatus.BAD_REQUEST);
        }

        bill.setThreeWayMatchStatus(STATUS_OVERRIDDEN);
        bill.setThreeWayMatchAt(Instant.now());
        bill.setThreeWayMatchOverriddenBy(userId);
        bill.setThreeWayMatchOverrideReason(reason);
        billRepository.save(bill);
    }

    @Transactional(readOnly = true)
    public MatchSnapshot get(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseBill", billId));
        List<BillMatchResultLine> lines = matchResultRepository.findByOrgIdAndBillId(orgId, billId);
        return new MatchSnapshot(
                bill.getId(), bill.getBillNumber(),
                bill.getThreeWayMatchStatus(),
                bill.getThreeWayMatchAt(),
                bill.getThreeWayMatchOverriddenBy(),
                bill.getThreeWayMatchOverrideReason(),
                lines);
    }

    /** All non-MATCHED, non-BYPASSED line statuses — every variance an AP team
     *  should review (qty over-receipt, price hike, amount mismatch, missing
     *  PO link, missing GRN). MATCHED + BYPASSED are excluded by design. */
    static final List<String> EXCEPTION_LINE_STATUSES = List.of(
            LINE_QTY_OVER, LINE_PRICE_HIKE, LINE_AMOUNT_MISMATCH,
            LINE_NO_PO, LINE_NO_GRN);

    @Transactional(readOnly = true)
    public Page<BillMatchResultLine> listExceptions(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return matchResultRepository.findByOrgIdAndStatusIn(
                orgId, EXCEPTION_LINE_STATUSES, pageable);
    }

    // ── Tolerance loading ────────────────────────────────────────────

    Tolerances loadTolerances(UUID orgId) {
        boolean required = "true".equalsIgnoreCase(
                orgSettingsService.get(orgId, "ap.three_way_match.required", "true"));
        BigDecimal qtyPct = parseBigDecimal(
                orgSettingsService.get(orgId, "ap.three_way_match.qty_tolerance_pct", "0"),
                BigDecimal.ZERO);
        BigDecimal priceAbs = parseBigDecimal(
                orgSettingsService.get(orgId, "ap.three_way_match.price_tolerance_abs", "1"),
                BigDecimal.ONE);
        BigDecimal pricePct = parseBigDecimal(
                orgSettingsService.get(orgId, "ap.three_way_match.price_tolerance_pct", "0.005"),
                new BigDecimal("0.005"));
        BigDecimal bypass = parseBigDecimal(
                orgSettingsService.get(orgId, "ap.three_way_match.bypass_threshold", "0"),
                BigDecimal.ZERO);
        return new Tolerances(required, qtyPct, priceAbs, pricePct, bypass);
    }

    // ── Per-line matching ────────────────────────────────────────────

    private BillMatchResultLine matchLine(PurchaseBill bill, PurchaseBillLine line,
                                          UUID orgId, Tolerances tol) {
        BillMatchResultLine.BillMatchResultLineBuilder b = BillMatchResultLine.builder()
                .orgId(orgId).billId(bill.getId()).billLineId(line.getId())
                .itemId(line.getItemId())
                .billedQty(line.getQuantity())
                .billUnitPrice(line.getUnitPrice());

        // Bypass: bill total below threshold and no PO link — small purchases / petty-cash
        // bills don't need to march through the full match ceremony.
        if (line.getPurchaseOrderLineId() == null
                && tol.bypassThreshold.signum() > 0
                && bill.getTotalAmount() != null
                && bill.getTotalAmount().compareTo(tol.bypassThreshold) < 0) {
            return b.status(LINE_BYPASSED).build();
        }

        if (line.getPurchaseOrderLineId() == null) {
            return b.status(LINE_NO_PO).build();
        }

        Optional<PurchaseOrderLine> polOpt =
                purchaseOrderLineRepository.findById(line.getPurchaseOrderLineId());
        if (polOpt.isEmpty()) {
            // FK dangles — treat as NO_PO; the planner can clean it up.
            return b.status(LINE_NO_PO).build();
        }
        PurchaseOrderLine pol = polOpt.get();
        b.poLineId(pol.getId())
                .orderedQty(pol.getQuantity())
                .poUnitPrice(pol.getUnitPrice())
                .qtyVariance(line.getQuantity().subtract(pol.getQuantity()))
                .priceVariance(line.getUnitPrice().subtract(pol.getUnitPrice()))
                .amountVariance(line.getQuantity().multiply(line.getUnitPrice())
                        .subtract(pol.getQuantity().multiply(pol.getUnitPrice())));

        // SERVICE items skip the GRN check — services don't deduct into stock.
        Item item = line.getItemId() != null
                ? itemRepository.findById(line.getItemId()).orElse(null)
                : null;
        boolean isService = item != null && item.getItemType() == ItemType.SERVICE;

        if (!isService) {
            BigDecimal received = stockReceiptLineRepository
                    .sumReceivedQuantityForPurchaseOrderLine(pol.getId());
            if (received == null) received = BigDecimal.ZERO;
            b.receivedQty(received);

            if (received.signum() == 0) {
                return b.status(LINE_NO_GRN).build();
            }

            BigDecimal qtyAllowed = received.multiply(
                    BigDecimal.ONE.add(tol.qtyTolerancePct
                            .divide(new BigDecimal("100"), 6, RoundingMode.HALF_UP)));
            if (line.getQuantity().compareTo(qtyAllowed) > 0) {
                return b.status(LINE_QTY_OVER).build();
            }
        }

        // Price variance: abs OR pct, whichever is more permissive
        BigDecimal poPrice = pol.getUnitPrice();
        BigDecimal absDiff = line.getUnitPrice().subtract(poPrice).abs();
        BigDecimal pctTol = poPrice.multiply(tol.priceTolerancePct).abs();
        BigDecimal effectiveTol = tol.priceToleranceAbs.max(pctTol);
        if (absDiff.compareTo(effectiveTol) > 0) {
            return b.status(LINE_PRICE_HIKE).build();
        }

        return b.status(LINE_MATCHED).build();
    }

    String computeOverallStatus(List<BillMatchResultLine> results, PurchaseBill bill, Tolerances tol) {
        if (results.isEmpty()) {
            return STATUS_MATCHED;
        }
        boolean allBypassed = results.stream().allMatch(r -> LINE_BYPASSED.equals(r.getStatus()));
        if (allBypassed) {
            return STATUS_BYPASSED;
        }
        boolean anyException = results.stream().anyMatch(r ->
                !LINE_MATCHED.equals(r.getStatus())
                        && !LINE_BYPASSED.equals(r.getStatus()));
        return anyException ? STATUS_EXCEPTION : STATUS_MATCHED;
    }

    // ── AI suggestion on EXCEPTION ───────────────────────────────────

    private void createSuggestionIfAbsent(PurchaseBill bill, List<BillMatchResultLine> results) {
        boolean exists = aiSuggestionRepository.existsOpenSuggestion(
                bill.getOrgId(), ENTITY_TYPE, bill.getId(), null,
                SUGGESTION_TYPE, OPEN_STATUSES);
        if (exists) return;

        String worst = results.stream()
                .filter(r -> !LINE_MATCHED.equals(r.getStatus())
                        && !LINE_BYPASSED.equals(r.getStatus()))
                .findFirst()
                .map(BillMatchResultLine::getStatus)
                .orElse(LINE_AMOUNT_MISMATCH);
        long exceptionCount = results.stream()
                .filter(r -> !LINE_MATCHED.equals(r.getStatus())
                        && !LINE_BYPASSED.equals(r.getStatus()))
                .count();

        Map<String, Object> payload = new HashMap<>();
        payload.put("billNumber", bill.getBillNumber());
        payload.put("worstStatus", worst);
        payload.put("exceptionLines", exceptionCount);

        String reasoning = "3-way match failed on " + exceptionCount
                + " line(s) — review variances. Worst: " + worst + ".";

        aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(bill.getOrgId())
                .entityType(ENTITY_TYPE)
                .entityId(bill.getId())
                .suggestionType(SUGGESTION_TYPE)
                .suggestedAction("REVIEW_VARIANCES")
                .suggestedValue(payload)
                .priority("HIGH")
                .reasoning(reasoning)
                .agentName("ThreeWayMatchService")
                .build());
    }

    // ── Helpers ──────────────────────────────────────────────────────

    private static BigDecimal parseBigDecimal(String s, BigDecimal fallback) {
        if (s == null || s.isBlank()) return fallback;
        try {
            return new BigDecimal(s.trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    public record Tolerances(
            boolean required,
            BigDecimal qtyTolerancePct,
            BigDecimal priceToleranceAbs,
            BigDecimal priceTolerancePct,
            BigDecimal bypassThreshold
    ) {}

    public record MatchSnapshot(
            UUID billId,
            String billNumber,
            String status,
            Instant matchedAt,
            UUID overriddenBy,
            String overrideReason,
            List<BillMatchResultLine> lines
    ) {}
}
