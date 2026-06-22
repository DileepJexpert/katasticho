package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.dto.GrnDraftFromScanRequest;
import com.katasticho.erp.ai.dto.GrnDraftResult;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.procurement.dto.CreateStockReceiptRequest;
import com.katasticho.erp.procurement.dto.StockReceiptLineRequest;
import com.katasticho.erp.procurement.dto.StockReceiptResponse;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.entity.PurchaseOrderLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.service.StockReceiptService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * AI-first goods-receipt drafting — the "scan the supplier's invoice and a
 * draft GRN is waiting in the AI Inbox" entry point. Mirrors
 * {@link BillDraftingService} but lands a {@code stock_receipt} (GRN) instead
 * of a {@code purchase_bill}.
 *
 * <p>When a PO is supplied, each scan line is fuzzy-matched against the PO's
 * lines by item name (case-insensitive contains, longest-match wins, exact
 * equals beats contains on ties). A matched line stamps both
 * {@code itemId} (from the PO master) and {@code purchaseOrderLineId} so the
 * P2P FK loop is preserved; unmatched lines still get drafted with whatever
 * the scan provided so the operator only has to fix the few that didn't
 * resolve. When no PO is supplied, the GRN is drafted standalone against the
 * caller-supplied {@code warehouseId} + {@code supplierId}.
 *
 * <p>Approving the suggestion calls {@link StockReceiptService#receive(UUID)}
 * which fires the existing inventory + provisional-COGS reconciliation paths.
 * Rejecting cancels the draft via {@link StockReceiptService#cancel(UUID, String)}
 * — never hard-deletes, so the audit trail keeps the failed attempt.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class GrnDraftingService {

    static final String SUGGESTION_TYPE = "DRAFT_GRN";
    static final String ENTITY_TYPE = "STOCK_RECEIPT";

    private final StockReceiptService stockReceiptService;
    private final PurchaseOrderRepository purchaseOrderRepository;
    private final PurchaseOrderLineRepository purchaseOrderLineRepository;
    private final ItemRepository itemRepository;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;

    // ── Draft ────────────────────────────────────────────────────────────

    /** Turn scanned GRN data into a DRAFT stock receipt + AI Inbox suggestion. */
    @Transactional
    public GrnDraftResult draftFromScan(GrnDraftFromScanRequest req) {
        UUID orgId = requireOrgId();
        List<String> warnings = new ArrayList<>();

        PoContext po = resolvePo(orgId, req);

        List<StockReceiptLineRequest> grnLines = new ArrayList<>();
        int unmatched = 0;
        Set<UUID> alreadyMatchedPoLineIds = new HashSet<>();
        for (GrnDraftFromScanRequest.ScanLine sl : req.lines()) {
            BigDecimal qty = sl.quantity() != null && sl.quantity().signum() > 0
                    ? sl.quantity() : BigDecimal.ONE;
            BigDecimal unitPrice = sl.unitPrice() != null ? sl.unitPrice() : BigDecimal.ZERO;
            String hsnRaw = trimToNull(sl.hsnCode());
            String description = trimToNull(sl.description());

            UUID itemId = null;
            UUID poLineId = null;
            String hsn = hsnRaw;
            BigDecimal gstRate = sl.gstRate();
            String uom = null;

            if (po != null && description != null) {
                PurchaseOrderLine match = pickBestPoMatch(description, po, alreadyMatchedPoLineIds);
                if (match != null) {
                    alreadyMatchedPoLineIds.add(match.getId());
                    poLineId = match.getId();
                    itemId = match.getItemId();
                    Item it = po.itemById().get(match.getItemId());
                    if (it != null) {
                        if (hsn == null) hsn = it.getHsnCode();
                        if (gstRate == null) gstRate = it.getGstRate();
                        uom = it.getUnitOfMeasure();
                    }
                    // PO unit price is the negotiated rate — only fall back to
                    // it when the scan didn't read one off the photo.
                    if (sl.unitPrice() == null || sl.unitPrice().signum() == 0) {
                        unitPrice = match.getUnitPrice();
                    }
                }
            }

            // Standalone GRN line with no PO link: every line MUST resolve to
            // an item (StockReceiptService validates @NotNull itemId). Try a
            // direct item-master name lookup as a last resort.
            if (itemId == null && po == null && description != null) {
                Item byName = itemRepository
                        .findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, description)
                        .orElse(null);
                if (byName != null) {
                    itemId = byName.getId();
                    if (hsn == null) hsn = byName.getHsnCode();
                    if (gstRate == null) gstRate = byName.getGstRate();
                    uom = byName.getUnitOfMeasure();
                }
            }

            if (itemId == null) {
                unmatched++;
                // Skip the line entirely when we can't resolve an item — the
                // GRN line gate requires itemId, and posting a bogus draft
                // hurts more than it helps. The unmatchedCount warning makes
                // the gap visible.
                continue;
            }

            grnLines.add(new StockReceiptLineRequest(
                    itemId,
                    description,
                    hsn,
                    qty.setScale(4, RoundingMode.HALF_UP),
                    uom,
                    unitPrice,
                    BigDecimal.ZERO,
                    gstRate,
                    trimToNull(sl.batchNumber()),
                    sl.expiryDate(),
                    null,
                    poLineId
            ));
        }

        if (grnLines.isEmpty()) {
            throw new BusinessException(
                    "No scan lines could be matched to an item — nothing to draft",
                    "GRN_DRAFT_NO_LINES",
                    HttpStatus.BAD_REQUEST);
        }
        if (unmatched > 0) {
            warnings.add(unmatched + " line(s) could not be matched to a known item — fix on the draft before approving");
        }

        UUID supplierId = po != null ? po.po().getSupplierId() : req.supplierId();
        if (supplierId == null) {
            throw new BusinessException(
                    "Supplier is required when drafting a GRN without a PO",
                    "GRN_DRAFT_SUPPLIER_REQUIRED",
                    HttpStatus.BAD_REQUEST);
        }

        UUID warehouseId = po != null ? po.po().getWarehouseId() : req.warehouseId();
        if (warehouseId == null) {
            // Stand-alone GRN with no warehouse on PO + none from the caller:
            // we COULD fall through to the StockReceiptService default, but
            // fail fast here so the operator sees the missing field instead
            // of a quietly-mis-routed receipt.
            throw new BusinessException(
                    "Warehouse is required when drafting a GRN without a PO",
                    "GRN_DRAFT_WAREHOUSE_REQUIRED",
                    HttpStatus.BAD_REQUEST);
        }

        LocalDate receiptDate = req.receiptDate() != null ? req.receiptDate() : LocalDate.now();
        CreateStockReceiptRequest createReq = new CreateStockReceiptRequest(
                supplierId,
                warehouseId,
                receiptDate,
                trimToNull(req.vendorBillNumber()),
                req.vendorBillDate(),
                req.notes(),
                null, null, null, null,
                po != null ? po.po().getId() : null,
                grnLines);

        StockReceiptResponse grn = stockReceiptService.createDraft(createReq);

        double confidence = clampConfidence(req.confidence());
        AiSuggestion suggestion = aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(orgId)
                .entityType(ENTITY_TYPE)
                .entityId(grn.id())
                .suggestionType(SUGGESTION_TYPE)
                .suggestedAction("REVIEW_AND_RECEIVE_GRN")
                .suggestedValue(buildSuggestedValue(grn, po, unmatched, req))
                .reasoning(buildReasoning(grn, po, unmatched))
                .confidence(toConfidence(confidence))
                .agentName("grn_drafter")
                .modelName("grn_scan+rules")
                .modelVersion("1")
                .promptVersion("none")
                .priority(unmatched > 0 || po == null ? "HIGH" : "MEDIUM")
                .priorityScore(unmatched > 0 ? new BigDecimal("80") : new BigDecimal("50"))
                .status("PENDING")
                .build());

        return new GrnDraftResult(
                suggestion.getId(), grn.id(), grn.receiptNumber(), grn.status(),
                supplierId, grn.supplierName(),
                po != null ? po.po().getId() : null,
                po != null ? po.po().getPoNumber() : null,
                grnLines.size(), unmatched, confidence, warnings);
    }

    // ── Approve / reject ─────────────────────────────────────────────────

    /** Approve a drafted GRN: post it through the receipt path, mark accepted. */
    @Transactional
    public GrnDraftResult approve(UUID suggestionId) {
        UUID orgId = requireOrgId();
        AiSuggestion suggestion = loadDraftGrnSuggestion(suggestionId, orgId);

        StockReceiptResponse received = stockReceiptService.receive(suggestion.getEntityId());

        Map<String, Object> reviewed = new HashMap<>();
        reviewed.put("received", true);
        reviewed.put("grnNumber", received.receiptNumber());
        aiSuggestionService.review(suggestionId, new AiSuggestionReviewRequest("ACCEPT", reviewed, null));

        return new GrnDraftResult(
                suggestionId, received.id(), received.receiptNumber(), received.status(),
                received.supplierId(), received.supplierName(),
                received.purchaseOrderId(), null,
                received.lines() == null ? 0 : received.lines().size(), 0,
                confidenceOf(suggestion), List.of());
    }

    /** Reject a drafted GRN: cancel the draft so the audit trail keeps it. */
    @Transactional
    public void reject(UUID suggestionId, String reason) {
        UUID orgId = requireOrgId();
        AiSuggestion suggestion = loadDraftGrnSuggestion(suggestionId, orgId);
        stockReceiptService.cancel(suggestion.getEntityId(),
                reason != null && !reason.isBlank() ? reason : "AI draft rejected");
        aiSuggestionService.review(suggestionId, new AiSuggestionReviewRequest("REJECT", null, reason));
    }

    // ── PO resolution ────────────────────────────────────────────────────

    private PoContext resolvePo(UUID orgId, GrnDraftFromScanRequest req) {
        if (req.purchaseOrderId() == null) return null;
        PurchaseOrder po = purchaseOrderRepository
                .findByIdAndOrgIdAndIsDeletedFalse(req.purchaseOrderId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("PurchaseOrder", req.purchaseOrderId()));
        if ("CANCELLED".equals(po.getStatus())) {
            throw new BusinessException(
                    "Cannot draft GRN from a cancelled purchase order",
                    "PO_CANCELLED", HttpStatus.BAD_REQUEST);
        }
        List<PurchaseOrderLine> lines = purchaseOrderLineRepository.findByPoId(po.getId());
        Map<UUID, Item> itemById = new HashMap<>();
        if (!lines.isEmpty()) {
            List<UUID> itemIds = lines.stream().map(PurchaseOrderLine::getItemId).toList();
            itemRepository.findAllById(itemIds).forEach(it -> itemById.put(it.getId(), it));
        }
        return new PoContext(po, lines, itemById);
    }

    /**
     * Fuzzy line matcher: case-insensitive contains, longest-match wins; on a
     * tie an exact-equals beats a contains. Already-bound PO lines are skipped
     * so two scan lines can't fall onto the same PO line — the second falls
     * back to unmatched, which the operator sees in the warnings count.
     */
    PurchaseOrderLine pickBestPoMatch(String scanDesc, PoContext po, Set<UUID> alreadyMatched) {
        String needle = scanDesc.toLowerCase();
        PurchaseOrderLine best = null;
        int bestScore = -1;
        boolean bestExact = false;
        for (PurchaseOrderLine pol : po.lines()) {
            if (alreadyMatched.contains(pol.getId())) continue;
            String hay = lookupName(pol, po).toLowerCase();
            if (hay.isEmpty()) continue;
            boolean exact = hay.equals(needle);
            boolean contains = hay.contains(needle) || needle.contains(hay);
            if (!exact && !contains) continue;
            int score = hay.length();
            // Exact match wins over any contains, regardless of length.
            if (exact && !bestExact) {
                best = pol; bestScore = score; bestExact = true;
                continue;
            }
            if (bestExact && !exact) continue;
            if (score > bestScore) {
                best = pol; bestScore = score;
            }
        }
        return best;
    }

    private String lookupName(PurchaseOrderLine pol, PoContext po) {
        Item it = po.itemById().get(pol.getItemId());
        if (it != null && it.getName() != null) return it.getName();
        return pol.getDescription() == null ? "" : pol.getDescription();
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private AiSuggestion loadDraftGrnSuggestion(UUID id, UUID orgId) {
        AiSuggestion s = aiSuggestionRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> new BusinessException(
                        "AI suggestion not found", "AI_SUGGESTION_NOT_FOUND", HttpStatus.NOT_FOUND));
        if (!SUGGESTION_TYPE.equals(s.getSuggestionType())) {
            throw new BusinessException(
                    "Suggestion is not a drafted GRN", "AI_NOT_DRAFT_GRN", HttpStatus.BAD_REQUEST);
        }
        return s;
    }

    private Map<String, Object> buildSuggestedValue(StockReceiptResponse grn, PoContext po,
                                                    int unmatched, GrnDraftFromScanRequest req) {
        Map<String, Object> sv = new HashMap<>();
        sv.put("grnNumber", grn.receiptNumber());
        sv.put("supplierName", grn.supplierName());
        sv.put("vendorBillNumber", req.vendorBillNumber());
        sv.put("lineCount", grn.lines() == null ? 0 : grn.lines().size());
        sv.put("unmatchedItemCount", unmatched);
        if (po != null) {
            sv.put("poNumber", po.po().getPoNumber());
        }
        return sv;
    }

    private String buildReasoning(StockReceiptResponse grn, PoContext po, int unmatched) {
        StringBuilder sb = new StringBuilder("Drafted GRN ").append(grn.receiptNumber());
        if (grn.supplierName() != null) {
            sb.append(" for ").append(grn.supplierName());
        }
        if (po != null) {
            sb.append(" against PO ").append(po.po().getPoNumber());
        } else {
            sb.append(" as a stand-alone receipt (no source PO)");
        }
        sb.append(" from a scanned document.");
        if (unmatched > 0) {
            sb.append(" ").append(unmatched)
              .append(" line(s) could not be matched to a known item and were skipped.");
        }
        sb.append(" Review and approve to post stock.");
        return sb.toString();
    }

    private double clampConfidence(Double raw) {
        if (raw == null) return 0.0;
        if (raw < 0) return 0.0;
        if (raw > 1) return 1.0;
        return raw;
    }

    private BigDecimal toConfidence(double confidence) {
        return BigDecimal.valueOf(confidence).setScale(3, RoundingMode.HALF_UP);
    }

    private double confidenceOf(AiSuggestion suggestion) {
        return suggestion.getConfidence() == null ? 0.0 : suggestion.getConfidence().doubleValue();
    }

    private String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }

    record PoContext(PurchaseOrder po, List<PurchaseOrderLine> lines, Map<UUID, Item> itemById) {}
}
