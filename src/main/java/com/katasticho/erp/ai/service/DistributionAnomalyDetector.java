package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Productised anomaly + fraud detection for distribution. Per the strategic
 * doc this is "the builder's reconciliation expertise applied as a product"
 * — and a documented zero in every Indian incumbent.
 *
 * <p>Each detector raises an {@link AiSuggestion} in the AI Inbox (open
 * state, priority by severity) so the operator can dispose them in the
 * normal review flow. All detectors are deterministic + audit-trail
 * friendly (no LLM call); reasons cite the rule + the evidence.
 *
 * <p>Catalogue (this round):
 * <ul>
 *   <li>{@link #scanDuplicateVendorPayments(int)} — same vendor + same
 *       amount within N days.</li>
 *   <li>{@link #scanMarginErosion(BigDecimal)} — items whose sale price
 *       drops below their purchase price (selling below cost).</li>
 *   <li>{@link #scanCreditLimitBreaches()} — contacts whose outstanding
 *       AR exceeds their stored {@code creditLimit}.</li>
 *   <li>{@link #scanScheme} (placeholder hooks for future).</li>
 * </ul>
 *
 * <p>{@link #runAll()} runs the full suite for the current org and returns
 * counters for the AI Inbox / Proactive Agents nightly job.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DistributionAnomalyDetector {

    private static final String AGENT_NAME = "distribution-anomaly";

    private final VendorPaymentRepository vendorPaymentRepository;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final com.katasticho.erp.inventory.repository.ItemRepository itemRepository;
    private final com.katasticho.erp.contact.repository.ContactRepository contactRepository;
    private final com.katasticho.erp.ar.repository.InvoiceRepository invoiceRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public Map<String, Object> runAll() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("duplicateVendorPayments", scanDuplicateVendorPayments(7));
        out.put("marginErosion", scanMarginErosion(BigDecimal.ZERO));
        out.put("creditLimitBreaches", scanCreditLimitBreaches());
        return out;
    }

    // ── Duplicate vendor payments ────────────────────────────────

    /**
     * Same vendor + same amount paid more than once within {@code windowDays}
     * → likely double-payment (cashier accidentally hit "post" twice, OR a
     * supplier sent two invoices for the same goods and we paid both).
     */
    @Transactional
    public int scanDuplicateVendorPayments(int windowDays) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate from = LocalDate.now().minusDays(windowDays);
        LocalDate to = LocalDate.now();

        var page = vendorPaymentRepository
                .findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
                        orgId, from, to, org.springframework.data.domain.PageRequest.of(0, 500));
        // Group by (contactId + amount); 2+ in a window = anomaly.
        Map<String, List<VendorPayment>> groups = new HashMap<>();
        for (VendorPayment p : page.getContent()) {
            BigDecimal amt = p.getAmount() == null ? BigDecimal.ZERO : p.getAmount();
            String key = p.getContactId() + "|" + amt.stripTrailingZeros().toPlainString();
            groups.computeIfAbsent(key, k -> new ArrayList<>()).add(p);
        }

        int raised = 0;
        for (var entry : groups.entrySet()) {
            if (entry.getValue().size() < 2) continue;
            VendorPayment p = entry.getValue().get(0);
            if (aiSuggestionRepository.existsOpenSuggestion(
                    orgId, "VENDOR_PAYMENT", p.getId(), null, "DUPLICATE_PAYMENT",
                    java.util.List.of("OPEN"))) continue;

            Map<String, Object> value = new LinkedHashMap<>();
            value.put("contactId", p.getContactId());
            value.put("amount", p.getAmount());
            value.put("paymentIds", entry.getValue().stream().map(VendorPayment::getId).toList());
            value.put("count", entry.getValue().size());

            String reason = "Same vendor paid ₹" + p.getAmount() + " "
                    + entry.getValue().size() + " times within " + windowDays
                    + " days. Likely double-payment — review and void duplicates if confirmed.";

            raise("VENDOR_PAYMENT", p.getId(), null,
                    "DUPLICATE_PAYMENT", "REVIEW_VENDOR_PAYMENT",
                    value, reason, 0.85, "HIGH");
            raised++;
        }
        return raised;
    }

    // ── Margin erosion (selling below cost) ──────────────────────

    /**
     * Items whose {@code salePrice} is below {@code purchasePrice}
     * (i.e. selling at a loss). {@code thresholdMargin} is the minimum
     * margin we expect, expressed as a fraction (0.0 = selling exactly
     * at cost, 0.05 = at least 5% above cost).
     */
    @Transactional
    public int scanMarginErosion(BigDecimal thresholdMargin) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal threshold = thresholdMargin == null ? BigDecimal.ZERO : thresholdMargin;
        int raised = 0;
        // Don't pull the full table — page in 500s.
        int pageSize = 500;
        int p = 0;
        while (true) {
            var page = itemRepository.findByOrgIdAndIsDeletedFalse(orgId,
                    org.springframework.data.domain.PageRequest.of(p, pageSize));
            for (var item : page.getContent()) {
                BigDecimal sale = item.getSalePrice();
                BigDecimal cost = item.getPurchasePrice();
                if (sale == null || cost == null) continue;
                if (cost.signum() <= 0) continue; // no cost recorded
                // marginRatio = (sale - cost) / cost
                BigDecimal ratio = sale.subtract(cost)
                        .divide(cost, 4, java.math.RoundingMode.HALF_UP);
                if (ratio.compareTo(threshold) >= 0) continue;

                if (aiSuggestionRepository.existsOpenSuggestion(
                        orgId, "ITEM", item.getId(), null, "MARGIN_EROSION",
                        java.util.List.of("OPEN"))) continue;

                Map<String, Object> value = new LinkedHashMap<>();
                value.put("itemName", item.getName());
                value.put("salePrice", sale);
                value.put("purchasePrice", cost);
                value.put("marginPct", ratio.multiply(new BigDecimal("100")));

                String reason = "Sale price ₹" + sale + " is "
                        + (sale.compareTo(cost) < 0 ? "below" : "barely above")
                        + " purchase price ₹" + cost + ". "
                        + "Selling-below-cost erodes the receivables ledger silently.";

                raise("ITEM", item.getId(), null,
                        "MARGIN_EROSION", "REVIEW_SALE_PRICE",
                        value, reason, 0.9,
                        sale.compareTo(cost) < 0 ? "HIGH" : "MEDIUM");
                raised++;
            }
            if (!page.hasNext()) break;
            p++;
        }
        return raised;
    }

    // ── Credit-limit breaches ────────────────────────────────────

    @Transactional
    public int scanCreditLimitBreaches() {
        UUID orgId = TenantContext.getCurrentOrgId();
        var customersPage = contactRepository.findByOrgIdAndContactTypeAndIsDeletedFalse(
                orgId, com.katasticho.erp.contact.entity.ContactType.CUSTOMER,
                org.springframework.data.domain.PageRequest.of(0, 1000));
        int raised = 0;
        for (var c : customersPage.getContent()) {
            BigDecimal creditLimit = c.getCreditLimit();
            if (creditLimit == null || creditLimit.signum() <= 0) continue; // unlimited

            // Sum balanceDue across outstanding invoices for this contact.
            BigDecimal outstanding = BigDecimal.ZERO;
            for (var inv : invoiceRepository.findOutstandingByContact(orgId, c.getId())) {
                BigDecimal bal = inv.getBalanceDue();
                if (bal != null) outstanding = outstanding.add(bal);
            }
            if (outstanding.compareTo(creditLimit) <= 0) continue;

            if (aiSuggestionRepository.existsOpenSuggestion(
                    orgId, "CONTACT", c.getId(), null, "CREDIT_LIMIT_BREACH",
                    java.util.List.of("OPEN"))) continue;

            BigDecimal over = outstanding.subtract(creditLimit);
            Map<String, Object> value = new LinkedHashMap<>();
            value.put("contactName", c.getDisplayName());
            value.put("creditLimit", creditLimit);
            value.put("outstanding", outstanding);
            value.put("overBy", over);

            String reason = c.getDisplayName() + " owes ₹" + outstanding
                    + " against a credit limit of ₹" + creditLimit
                    + " (over by ₹" + over + "). Hold further dispatches.";

            raise("CONTACT", c.getId(), null,
                    "CREDIT_LIMIT_BREACH", "FREEZE_CREDIT",
                    value, reason, 0.95, "HIGH");
            raised++;
        }
        return raised;
    }

    // ── helpers ──────────────────────────────────────────────────

    private void raise(String entityType, UUID entityId, UUID entityLineId,
                       String suggestionType, String action,
                       Map<String, Object> value, String reason,
                       double confidence, String priority) {
        try {
            AiSuggestion s = AiSuggestion.builder()
                    .orgId(TenantContext.getCurrentOrgId())
                    .entityType(entityType)
                    .entityId(entityId)
                    .entityLineId(entityLineId)
                    .suggestionType(suggestionType)
                    .suggestedAction(action)
                    .suggestedValue(value)
                    .reasoning(reason)
                    .confidence(BigDecimal.valueOf(confidence))
                    .agentName(AGENT_NAME)
                    .modelName("rule-based")
                    .status("OPEN")
                    .priority(priority)
                    .build();
            aiSuggestionRepository.save(s);
        } catch (Exception e) {
            log.warn("Anomaly suggestion save failed: {}", e.toString());
        }
    }
}
