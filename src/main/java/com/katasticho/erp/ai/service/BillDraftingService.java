package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.dto.BillDraftFromScanRequest;
import com.katasticho.erp.ai.dto.BillDraftResult;
import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.entity.AiPattern;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiPatternRepository;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ap.dto.CreatePurchaseBillRequest;
import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.ap.service.PurchaseBillService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * AI-first purchase bill drafting — the "draft, don't type" entry point.
 *
 * <p>Instead of an operator filling a blank bill form, the scanned (and
 * optionally reviewed) bill data is turned into a DRAFT {@code purchase_bill}
 * with the accounting work already done: the vendor is matched (or created),
 * each line is matched to an inventory item (GOODS) or booked as expense
 * (SERVICE), and the GST rate is taken from the bill or inferred from the HSN.
 * The draft is surfaced as a {@code DRAFT_BILL} suggestion in the AI Inbox.
 *
 * <p>Approving the suggestion posts the bill through the normal
 * {@link PurchaseBillService} path (so all validations and journal/stock
 * postings apply) and records what the human accepted as an {@link AiPattern}
 * so future drafts of the same vendor pre-fill the same account. Rejecting
 * deletes the DRAFT. The AI never posts anything on its own — a human always
 * approves.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BillDraftingService {

    static final String SUGGESTION_TYPE = "DRAFT_BILL";
    static final String ENTITY_TYPE = "PURCHASE_BILL";
    static final String PATTERN_TYPE = "PURCHASE_LINE_ACCOUNT";
    private static final BigDecimal HIGH_VALUE_THRESHOLD = new BigDecimal("100000");

    private final PurchaseBillService purchaseBillService;
    private final ContactRepository contactRepository;
    private final ItemRepository itemRepository;
    private final HsnGstMasterRepository hsnGstMasterRepository;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final AiPatternRepository aiPatternRepository;

    // ── Draft ────────────────────────────────────────────────────────────

    /** Turn scanned bill data into a DRAFT purchase bill + AI Inbox suggestion. */
    @Transactional
    public BillDraftResult draftFromScan(BillDraftFromScanRequest req) {
        UUID orgId = requireOrgId();
        List<String> warnings = new ArrayList<>();

        VendorResolution vendor = resolveVendor(orgId, req, warnings);
        UUID contactId = vendor.contact().getId();

        List<CreatePurchaseBillRequest.BillLineRequest> lines = new ArrayList<>();
        int unmatched = 0;
        for (BillDraftFromScanRequest.ScanLine sl : req.lines()) {
            String rawDesc = sl.description() == null ? "" : sl.description().trim();
            String description = rawDesc.isEmpty() ? "Item" : rawDesc;
            BigDecimal quantity = sl.quantity() == null ? BigDecimal.ONE : sl.quantity();
            BigDecimal unitPrice = sl.unitPrice() == null ? BigDecimal.ZERO : sl.unitPrice();
            BigDecimal gstRate = resolveGstRate(sl.gstRate(), sl.hsnCode());
            BigDecimal discountPercent = sl.discountPercent();

            Optional<Item> match = rawDesc.isEmpty()
                    ? Optional.empty()
                    : itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, rawDesc);

            String lineType;
            UUID itemId;
            UUID accountId;
            if (match.isPresent()) {
                lineType = "GOODS";
                itemId = match.get().getId();
                accountId = null; // PurchaseBillService falls back to the PURCHASE default
            } else {
                lineType = "SERVICE";
                itemId = null;
                // Reuse the account the human accepted last time for this vendor+HSN.
                accountId = learnedAccount(orgId, contactId, sl.hsnCode()).orElse(null);
                unmatched++;
            }

            lines.add(new CreatePurchaseBillRequest.BillLineRequest(
                    lineType, description, trimToNull(sl.hsnCode()), itemId, accountId, null,
                    quantity, unitPrice, discountPercent, gstRate, null, null, null));
        }

        if (unmatched > 0) {
            warnings.add(unmatched + " line(s) had no matching item and were booked as expense — review before posting");
        }

        LocalDate billDate = req.billDate() != null ? req.billDate() : LocalDate.now();
        CreatePurchaseBillRequest createReq = new CreatePurchaseBillRequest(
                contactId,
                trimToNull(req.invoiceNumber()),
                billDate,
                req.dueDate(),
                trimToNull(req.vendorStateCode()),
                false,
                req.notes(),
                null,
                null,
                lines);

        PurchaseBillResponse bill = purchaseBillService.createBill(createReq);

        double confidence = clampConfidence(req.confidence());
        AiSuggestion suggestion = aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(orgId)
                .entityType(ENTITY_TYPE)
                .entityId(bill.id())
                .suggestionType(SUGGESTION_TYPE)
                .suggestedAction("REVIEW_AND_POST_BILL")
                .suggestedValue(buildSuggestedValue(bill, vendor, unmatched, req))
                .reasoning(buildReasoning(bill, vendor, unmatched))
                .confidence(toConfidence(confidence))
                .agentName("bill_drafter")
                .modelName("bill_scan+rules")
                .modelVersion("1")
                .promptVersion("none")
                .priority(unmatched > 0 || isHighValue(bill) ? "HIGH" : "MEDIUM")
                .priorityScore(unmatched > 0 ? new BigDecimal("80") : new BigDecimal("50"))
                .status("PENDING")
                .build());

        return new BillDraftResult(
                suggestion.getId(), bill.id(), bill.billNumber(), bill.status(),
                contactId, vendor.contact().getDisplayName(), vendor.created(),
                bill.totalAmount(), lines.size(), unmatched, confidence, warnings);
    }

    // ── Approve / reject ─────────────────────────────────────────────────

    /** Approve a drafted bill: post it through the AP path, learn, mark accepted. */
    @Transactional
    public BillDraftResult approve(UUID suggestionId) {
        UUID orgId = requireOrgId();
        AiSuggestion suggestion = loadDraftBillSuggestion(suggestionId, orgId);

        PurchaseBillResponse posted = purchaseBillService.postBill(suggestion.getEntityId());

        // Learning must never block posting.
        try {
            learnFromPostedBill(orgId, posted);
        } catch (Exception e) {
            log.warn("AI pattern learning skipped for bill {}: {}", posted.billNumber(), e.getMessage());
        }

        Map<String, Object> reviewed = new HashMap<>();
        reviewed.put("posted", true);
        reviewed.put("billNumber", posted.billNumber());
        aiSuggestionService.review(suggestionId, new AiSuggestionReviewRequest("ACCEPT", reviewed, null));

        return new BillDraftResult(
                suggestionId, posted.id(), posted.billNumber(), posted.status(),
                posted.contactId(), posted.vendorName(), false,
                posted.totalAmount(), posted.lines() == null ? 0 : posted.lines().size(), 0,
                confidenceOf(suggestion), List.of());
    }

    /** Reject a drafted bill: delete the DRAFT and mark the suggestion rejected. */
    @Transactional
    public void reject(UUID suggestionId, String reason) {
        UUID orgId = requireOrgId();
        AiSuggestion suggestion = loadDraftBillSuggestion(suggestionId, orgId);
        purchaseBillService.deleteBill(suggestion.getEntityId());
        aiSuggestionService.review(suggestionId, new AiSuggestionReviewRequest("REJECT", null, reason));
    }

    // ── Vendor resolution ────────────────────────────────────────────────

    private VendorResolution resolveVendor(UUID orgId, BillDraftFromScanRequest req, List<String> warnings) {
        String gstin = trimToNull(req.vendorGstin());
        String name = trimToNull(req.vendorName());

        if (gstin != null) {
            Optional<Contact> byGstin = contactRepository
                    .findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(orgId, gstin);
            if (byGstin.isPresent()) {
                return new VendorResolution(ensureCanSupply(byGstin.get()), false);
            }
        }
        if (name != null) {
            Optional<Contact> byName = contactRepository
                    .findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, name);
            if (byName.isPresent()) {
                return new VendorResolution(ensureCanSupply(byName.get()), false);
            }
        }

        Contact vendor = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName(name != null ? name : "Unknown Vendor")
                .gstin(gstin)
                .gstTreatment(gstin != null && gstin.length() == 15
                        ? GstTreatment.REGISTERED : GstTreatment.UNREGISTERED)
                .placeOfSupply(trimToNull(req.vendorStateCode()))
                .billingStateCode(trimToNull(req.vendorStateCode()))
                .build();
        vendor.setOrgId(orgId);
        vendor = contactRepository.save(vendor);
        warnings.add("New vendor created: " + vendor.getDisplayName());
        return new VendorResolution(vendor, true);
    }

    /** A purchase bill's contact must be VENDOR or BOTH; promote a CUSTOMER match. */
    private Contact ensureCanSupply(Contact c) {
        if (c.getContactType() == ContactType.CUSTOMER) {
            c.setContactType(ContactType.BOTH);
            contactRepository.save(c);
        }
        return c;
    }

    // ── GST inference ────────────────────────────────────────────────────

    private BigDecimal resolveGstRate(BigDecimal scanned, String hsn) {
        if (scanned != null && scanned.compareTo(BigDecimal.ZERO) > 0) {
            return scanned;
        }
        String code = trimToNull(hsn);
        if (code != null) {
            return hsnGstMasterRepository.findByHsnCodeAndActiveTrue(code)
                    .map(HsnGstMaster::getGstRate)
                    .orElse(BigDecimal.ZERO);
        }
        return BigDecimal.ZERO;
    }

    // ── Learning (vendor + HSN → account) ────────────────────────────────

    private Optional<UUID> learnedAccount(UUID orgId, UUID contactId, String hsn) {
        String key = patternKey(contactId, hsn);
        for (AiPattern p : aiPatternRepository
                .findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(orgId, PATTERN_TYPE, "ACTIVE")) {
            if (key.equals(p.getPatternKey().get("key"))) {
                Object accountId = p.getPredictedResult().get("accountId");
                if (accountId != null) {
                    return Optional.of(UUID.fromString(accountId.toString()));
                }
            }
        }
        return Optional.empty();
    }

    private void learnFromPostedBill(UUID orgId, PurchaseBillResponse bill) {
        UUID contactId = bill.contactId();
        if (contactId == null || bill.lines() == null) {
            return;
        }
        for (PurchaseBillResponse.LineResponse line : bill.lines()) {
            recordAccountPattern(orgId, contactId, line.hsnCode(), line.accountId());
        }
    }

    private void recordAccountPattern(UUID orgId, UUID contactId, String hsn, UUID accountId) {
        if (accountId == null) {
            return;
        }
        String key = patternKey(contactId, hsn);
        for (AiPattern p : aiPatternRepository
                .findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(orgId, PATTERN_TYPE, "ACTIVE")) {
            if (key.equals(p.getPatternKey().get("key"))) {
                Map<String, Object> result = new HashMap<>();
                result.put("accountId", accountId.toString());
                p.setPredictedResult(result);
                p.setMatchCount(p.getMatchCount() + 1);
                p.setAcceptedCount(p.getAcceptedCount() + 1);
                p.setLastMatchedAt(Instant.now());
                aiPatternRepository.save(p);
                return;
            }
        }
        Map<String, Object> patternKey = new HashMap<>();
        patternKey.put("key", key);
        patternKey.put("contactId", contactId.toString());
        patternKey.put("hsn", hsn == null ? "" : hsn);
        Map<String, Object> result = new HashMap<>();
        result.put("accountId", accountId.toString());
        aiPatternRepository.save(AiPattern.builder()
                .orgId(orgId)
                .patternType(PATTERN_TYPE)
                .patternKey(patternKey)
                .predictedResult(result)
                .confidence(new BigDecimal("0.600"))
                .matchCount(1)
                .acceptedCount(1)
                .status("ACTIVE")
                .lastMatchedAt(Instant.now())
                .build());
    }

    private String patternKey(UUID contactId, String hsn) {
        return contactId + "|" + (hsn == null ? "" : hsn.trim());
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private AiSuggestion loadDraftBillSuggestion(UUID id, UUID orgId) {
        AiSuggestion s = aiSuggestionRepository.findByIdAndOrgId(id, orgId)
                .orElseThrow(() -> new BusinessException(
                        "AI suggestion not found", "AI_SUGGESTION_NOT_FOUND", HttpStatus.NOT_FOUND));
        if (!SUGGESTION_TYPE.equals(s.getSuggestionType())) {
            throw new BusinessException(
                    "Suggestion is not a drafted bill", "AI_NOT_DRAFT_BILL", HttpStatus.BAD_REQUEST);
        }
        return s;
    }

    private Map<String, Object> buildSuggestedValue(PurchaseBillResponse bill, VendorResolution vendor,
                                                    int unmatched, BillDraftFromScanRequest req) {
        Map<String, Object> sv = new HashMap<>();
        sv.put("billNumber", bill.billNumber());
        sv.put("vendorName", vendor.contact().getDisplayName());
        sv.put("invoiceNumber", req.invoiceNumber());
        sv.put("totalAmount", bill.totalAmount() == null ? null : bill.totalAmount().toPlainString());
        sv.put("lineCount", bill.lines() == null ? 0 : bill.lines().size());
        sv.put("unmatchedItemCount", unmatched);
        sv.put("vendorCreated", vendor.created());
        return sv;
    }

    private String buildReasoning(PurchaseBillResponse bill, VendorResolution vendor, int unmatched) {
        StringBuilder sb = new StringBuilder("Drafted bill ").append(bill.billNumber())
                .append(" for ").append(vendor.contact().getDisplayName());
        if (bill.totalAmount() != null) {
            sb.append(" totalling ").append(bill.totalAmount().toPlainString());
        }
        sb.append(" from a scanned document.");
        if (vendor.created()) {
            sb.append(" A new vendor was created.");
        }
        if (unmatched > 0) {
            sb.append(" ").append(unmatched)
              .append(" line(s) had no matching item and were booked as expense.");
        }
        sb.append(" Review and approve to post.");
        return sb.toString();
    }

    private boolean isHighValue(PurchaseBillResponse bill) {
        return bill.totalAmount() != null && bill.totalAmount().compareTo(HIGH_VALUE_THRESHOLD) >= 0;
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

    private record VendorResolution(Contact contact, boolean created) {}
}
