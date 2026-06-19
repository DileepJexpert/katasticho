package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.ai.dto.CategorySuggestion;
import com.katasticho.erp.ai.entity.AiPattern;
import com.katasticho.erp.ai.repository.AiPatternRepository;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.PurchaseBillLine;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Auto-categorize transactions agent — "propose the account, don't make me pick it".
 *
 * <p>When an operator enters a bill line with no expense account chosen, this
 * service suggests one from history: the GL account this vendor's lines were
 * booked to before, keyed by vendor (+ HSN when available). It reads the same
 * {@link AiPattern} rows that {@link BillDraftingService} writes when a drafted
 * bill is approved, so the two flows share one learned memory.
 *
 * <p>{@link #backfillFromHistory(int)} seeds that memory from already-posted
 * bills so suggestions work on day one, before any AI Inbox approval has
 * happened. The agent only ever <em>suggests</em> — a human still books the line.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TransactionCategorizationService {

    /** Shared with {@link BillDraftingService} so both read/write the same memory. */
    private static final String PATTERN_TYPE = BillDraftingService.PATTERN_TYPE;
    private static final BigDecimal MIN_BACKFILL_CONFIDENCE = new BigDecimal("0.500");
    private static final BigDecimal MAX_BACKFILL_CONFIDENCE = new BigDecimal("0.950");

    private final AiPatternRepository aiPatternRepository;
    private final AccountRepository accountRepository;
    private final PurchaseBillRepository purchaseBillRepository;

    // ── Suggest ──────────────────────────────────────────────────────────

    /**
     * Predict the GL account for a vendor's purchase line. Prefers an exact
     * vendor+HSN match, then falls back to a vendor-only match. Returns empty
     * when nothing has been learned yet for the vendor.
     */
    @Transactional(readOnly = true)
    public Optional<CategorySuggestion> suggest(UUID contactId, String hsn) {
        UUID orgId = requireOrgId();
        if (contactId == null) {
            return Optional.empty();
        }
        String normHsn = hsn == null ? "" : hsn.trim();
        String contactKey = contactId.toString();

        // Patterns come back confidence-desc, so the first match in each tier wins.
        List<AiPattern> patterns = aiPatternRepository
                .findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(orgId, PATTERN_TYPE, "ACTIVE");

        AiPattern exact = null;
        AiPattern vendorOnly = null;
        for (AiPattern p : patterns) {
            Map<String, Object> key = p.getPatternKey();
            if (key == null || !contactKey.equals(asString(key.get("contactId")))) {
                continue;
            }
            if (vendorOnly == null) {
                vendorOnly = p;
            }
            if (exact == null && normHsn.equals(asString(key.get("hsn")))) {
                exact = p;
            }
        }

        AiPattern chosen = exact != null ? exact : vendorOnly;
        if (chosen == null) {
            return Optional.empty();
        }
        String source = chosen == exact ? "EXACT" : "VENDOR";
        return toSuggestion(orgId, chosen, source);
    }

    private Optional<CategorySuggestion> toSuggestion(UUID orgId, AiPattern p, String source) {
        Object accountIdRaw = p.getPredictedResult() == null ? null : p.getPredictedResult().get("accountId");
        if (accountIdRaw == null) {
            return Optional.empty();
        }
        UUID accountId;
        try {
            accountId = UUID.fromString(accountIdRaw.toString());
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
        Optional<Account> account = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId);
        if (account.isEmpty()) {
            return Optional.empty(); // account deleted since the pattern was learned
        }
        Account a = account.get();
        double confidence = p.getConfidence() == null ? 0.5 : p.getConfidence().doubleValue();
        return Optional.of(new CategorySuggestion(
                accountId, a.getCode(), a.getName(), confidence, source, p.getMatchCount()));
    }

    // ── Backfill from history ────────────────────────────────────────────

    /**
     * Learn vendor→account patterns from posted bills in the last {@code lookbackDays}.
     * For each (vendor, HSN) it picks the most-frequently-used account and writes a
     * pattern whose confidence reflects how consistent that history is. Idempotent:
     * re-running refreshes the same patterns rather than duplicating them.
     *
     * @return number of (vendor, HSN) patterns created or refreshed
     */
    @Transactional
    public int backfillFromHistory(int lookbackDays) {
        UUID orgId = requireOrgId();
        int days = lookbackDays <= 0 ? 365 : lookbackDays;
        LocalDate to = LocalDate.now();
        LocalDate from = to.minusDays(days);

        List<PurchaseBill> bills = purchaseBillRepository.findPostedByOrgAndDateRange(orgId, from, to);

        // key -> (accountId -> observation count)
        Map<String, Map<UUID, Integer>> tally = new HashMap<>();
        Map<String, UUID> keyContact = new HashMap<>();
        Map<String, String> keyHsn = new HashMap<>();
        for (PurchaseBill bill : bills) {
            UUID contactId = bill.getContactId();
            if (contactId == null || bill.getLines() == null) {
                continue;
            }
            for (PurchaseBillLine line : bill.getLines()) {
                if (line.getAccountId() == null) {
                    continue;
                }
                String hsn = line.getHsnCode() == null ? "" : line.getHsnCode().trim();
                String key = patternKey(contactId, hsn);
                tally.computeIfAbsent(key, k -> new HashMap<>())
                        .merge(line.getAccountId(), 1, Integer::sum);
                keyContact.putIfAbsent(key, contactId);
                keyHsn.putIfAbsent(key, hsn);
            }
        }

        List<AiPattern> existing = new java.util.ArrayList<>(aiPatternRepository
                .findByOrgIdAndPatternTypeAndStatusOrderByConfidenceDesc(orgId, PATTERN_TYPE, "ACTIVE"));

        int learned = 0;
        for (Map.Entry<String, Map<UUID, Integer>> e : tally.entrySet()) {
            String key = e.getKey();
            Map<UUID, Integer> counts = e.getValue();
            int total = counts.values().stream().mapToInt(Integer::intValue).sum();
            UUID best = null;
            int bestCount = 0;
            for (Map.Entry<UUID, Integer> c : counts.entrySet()) {
                if (c.getValue() > bestCount) {
                    best = c.getKey();
                    bestCount = c.getValue();
                }
            }
            if (best == null) {
                continue;
            }
            BigDecimal confidence = clampBackfillConfidence(bestCount, total);
            // matchCount = total observations for the key, reflecting how much history backs it.
            upsertPattern(orgId, existing, key, keyContact.get(key), keyHsn.get(key), best, total, confidence);
            learned++;
        }
        log.info("Categorization backfill for org {}: learned {} vendor-account pattern(s) from {} bill(s)",
                orgId, learned, bills.size());
        return learned;
    }

    private void upsertPattern(UUID orgId, List<AiPattern> existing, String key, UUID contactId,
                               String hsn, UUID accountId, int matchCount, BigDecimal confidence) {
        Map<String, Object> result = new HashMap<>();
        result.put("accountId", accountId.toString());
        for (AiPattern p : existing) {
            if (p.getPatternKey() != null && key.equals(asString(p.getPatternKey().get("key")))) {
                p.setPredictedResult(result);
                p.setConfidence(confidence);
                p.setMatchCount(Math.max(p.getMatchCount(), matchCount));
                p.setLastMatchedAt(Instant.now());
                aiPatternRepository.save(p);
                return;
            }
        }
        Map<String, Object> patternKey = new HashMap<>();
        patternKey.put("key", key);
        patternKey.put("contactId", contactId.toString());
        patternKey.put("hsn", hsn == null ? "" : hsn);
        AiPattern saved = aiPatternRepository.save(AiPattern.builder()
                .orgId(orgId)
                .patternType(PATTERN_TYPE)
                .patternKey(patternKey)
                .predictedResult(result)
                .confidence(confidence)
                .matchCount(matchCount)
                .acceptedCount(0)
                .status("ACTIVE")
                .lastMatchedAt(Instant.now())
                .build());
        existing.add(saved); // so a later (vendor, HSN="") doesn't re-create the same key
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    /** Matches {@link BillDraftingService}'s key format so the memory is shared. */
    private String patternKey(UUID contactId, String hsn) {
        return contactId + "|" + (hsn == null ? "" : hsn.trim());
    }

    private BigDecimal clampBackfillConfidence(int best, int total) {
        if (total <= 0) {
            return MIN_BACKFILL_CONFIDENCE;
        }
        BigDecimal ratio = BigDecimal.valueOf(best)
                .divide(BigDecimal.valueOf(total), 3, RoundingMode.HALF_UP);
        if (ratio.compareTo(MIN_BACKFILL_CONFIDENCE) < 0) {
            return MIN_BACKFILL_CONFIDENCE;
        }
        if (ratio.compareTo(MAX_BACKFILL_CONFIDENCE) > 0) {
            return MAX_BACKFILL_CONFIDENCE;
        }
        return ratio;
    }

    private static String asString(Object o) {
        return o == null ? null : o.toString();
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
