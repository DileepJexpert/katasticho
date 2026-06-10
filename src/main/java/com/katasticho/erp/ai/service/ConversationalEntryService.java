package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ai.dto.AiSuggestionReviewRequest;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryDraftResult;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryLine;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Conversational entry — the AI-first "type a sentence, get a drafted
 * transaction" front door. "paid 5000 cash for shop rent" becomes a balanced
 * DRAFT journal entry (Dr Rent Expense, Cr Cash) plus a {@code DRAFT_ENTRY}
 * suggestion in the AI Inbox. The human approves to post.
 *
 * <p><b>Safety:</b> nothing posts automatically. The draft goes through the
 * single posting gate ({@link JournalService}) in DRAFT status; approving calls
 * {@link JournalService#postEntry}; rejecting deletes the draft.
 *
 * <p><b>Engine:</b> a deterministic rule-based parser (no external AI call) so
 * the feature works offline and is fully testable. It recognises the daily
 * cash/bank drivers — payments and receipts — resolves the party (customer→AR,
 * vendor→AP), the instrument (cash/bank), and the expense/income account by
 * keyword against the chart of accounts.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ConversationalEntryService {

    static final String SUGGESTION_TYPE = "DRAFT_ENTRY";
    static final String ENTITY_TYPE = "JOURNAL_ENTRY";

    private final JournalService journalService;
    private final AccountRepository accountRepository;
    private final ContactRepository contactRepository;
    private final DefaultAccountService defaultAccountService;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;

    private static final Pattern AMOUNT = Pattern.compile(
            "(?:rs\\.?|inr|₹)?\\s*([0-9][0-9,]*(?:\\.[0-9]+)?)\\s*(k|lakh|lakhs|lac|lacs|cr|crore|crores)?",
            Pattern.CASE_INSENSITIVE);

    // ── Draft ────────────────────────────────────────────────────────────

    @Transactional
    public EntryDraftResult draftFromText(String rawText) {
        UUID orgId = requireOrgId();
        String text = rawText == null ? "" : rawText.trim();
        if (text.isEmpty()) {
            return notDrafted("Type what happened, e.g. \"paid 5000 cash for shop rent\".");
        }

        Parsed p = parse(orgId, text);
        if (p.error != null) {
            return notDrafted(p.error);
        }

        List<JournalLineRequest> jLines = List.of(
                new JournalLineRequest(p.debitCode, p.amount, BigDecimal.ZERO, p.narration, null, null),
                new JournalLineRequest(p.creditCode, BigDecimal.ZERO, p.amount, p.narration, null, null));

        JournalEntry entry = journalService.postJournal(new JournalPostRequest(
                LocalDate.now(), p.narration, "AI_ENTRY", null, jLines, false));

        List<EntryLine> lines = List.of(
                new EntryLine(p.debitCode, nameOf(orgId, p.debitCode), p.amount, BigDecimal.ZERO),
                new EntryLine(p.creditCode, nameOf(orgId, p.creditCode), BigDecimal.ZERO, p.amount));

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("voucherType", p.voucherType);
        summary.put("narration", p.narration);
        summary.put("amount", p.amount);
        summary.put("debit", p.debitCode + " " + nameOf(orgId, p.debitCode));
        summary.put("credit", p.creditCode + " " + nameOf(orgId, p.creditCode));

        AiSuggestion suggestion = aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(orgId)
                .entityType(ENTITY_TYPE)
                .entityId(entry.getId())
                .suggestionType(SUGGESTION_TYPE)
                .suggestedAction("REVIEW_AND_POST_ENTRY")
                .suggestedValue(summary)
                .reasoning("Parsed from: \"" + text + "\"")
                .confidence(BigDecimal.valueOf(p.confidence))
                .agentName("conversational_entry")
                .modelName("rules")
                .modelVersion("1")
                .promptVersion("none")
                .priority(p.warnings.isEmpty() ? "MEDIUM" : "HIGH")
                .priorityScore(p.warnings.isEmpty() ? new BigDecimal("50") : new BigDecimal("75"))
                .status("PENDING")
                .build());

        log.info("Conversational entry drafted: {} {} (entry {})",
                p.voucherType, p.amount, entry.getEntryNumber());
        return new EntryDraftResult(true, suggestion.getId(), entry.getId(), p.voucherType,
                p.narration, p.amount, p.confidence, lines, p.warnings, null);
    }

    // ── Approve / reject ─────────────────────────────────────────────────

    @Transactional
    public EntryDraftResult approve(UUID suggestionId) {
        UUID orgId = requireOrgId();
        AiSuggestion s = loadDraftEntrySuggestion(suggestionId, orgId);

        JournalEntry posted = journalService.postEntry(s.getEntityId());

        Map<String, Object> reviewed = new HashMap<>();
        reviewed.put("posted", true);
        reviewed.put("entryNumber", posted.getEntryNumber());
        aiSuggestionService.review(suggestionId, new AiSuggestionReviewRequest("ACCEPT", reviewed, null));

        return new EntryDraftResult(true, suggestionId, posted.getId(), null,
                posted.getDescription(), null, confidenceOf(s), List.of(), List.of(), "Posted");
    }

    @Transactional
    public void reject(UUID suggestionId, String reason) {
        UUID orgId = requireOrgId();
        AiSuggestion s = loadDraftEntrySuggestion(suggestionId, orgId);
        journalService.deleteEntry(s.getEntityId());
        aiSuggestionService.review(suggestionId, new AiSuggestionReviewRequest("REJECT", null, reason));
    }

    // ── Rule-based parsing ───────────────────────────────────────────────

    private static final class Parsed {
        String voucherType;
        String narration;
        BigDecimal amount;
        String debitCode;
        String creditCode;
        double confidence = 0.6;
        final List<String> warnings = new ArrayList<>();
        String error;
    }

    private Parsed parse(UUID orgId, String text) {
        Parsed p = new Parsed();
        String lower = text.toLowerCase(Locale.ROOT);

        boolean outflow = containsAny(lower, "paid", "pay ", "spent", "spend", "purchased", "bought", "gave");
        boolean inflow = containsAny(lower, "received", "recd", "got ", "collected", "deposit", "credited");
        if (outflow == inflow) {
            // Neither or both → can't tell direction.
            p.error = "Start with \"paid …\" or \"received …\" so I know the direction. "
                    + "e.g. \"paid 5000 cash for shop rent\" or \"received 12000 from MediMart\".";
            return p;
        }

        BigDecimal amount = extractAmount(lower);
        if (amount == null || amount.signum() <= 0) {
            p.error = "I couldn't find an amount. Try e.g. \"paid 5000 cash for rent\".";
            return p;
        }
        p.amount = amount;

        String instrumentCode = instrumentCode(orgId, lower);   // cash or bank
        String party = extractParty(text, lower, outflow ? " to " : " from ");
        String purpose = extractPurpose(text, lower);
        Optional<Contact> contact = party == null ? Optional.empty()
                : contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, party);

        if (outflow) {
            p.voucherType = "PAYMENT";
            p.creditCode = instrumentCode;
            // Counter (debit) account: expense by purpose → vendor payable → fallback expense.
            String expenseCode = matchAccountByKeywords(orgId, purpose, "EXPENSE");
            if (expenseCode != null) {
                p.debitCode = expenseCode;
                p.confidence = 0.8;
            } else if (contact.isPresent() && contact.get().getContactType() != ContactType.CUSTOMER) {
                p.debitCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP);
                p.warnings.add("Booked against the supplier's payable — change the account if this was an expense.");
            } else {
                p.debitCode = fallbackExpenseCode(orgId);
                p.warnings.add("Couldn't tell which expense this is — booked to "
                        + nameOf(orgId, p.debitCode) + ". Please correct before approving.");
                p.confidence = 0.4;
            }
        } else {
            p.voucherType = "RECEIPT";
            p.debitCode = instrumentCode;
            // Counter (credit) account: customer receivable → income by purpose → fallback revenue.
            if (contact.isPresent() && contact.get().getContactType() != ContactType.VENDOR) {
                p.creditCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR);
                p.confidence = 0.8;
            } else {
                String incomeCode = matchAccountByKeywords(orgId, purpose, "REVENUE");
                if (incomeCode != null) {
                    p.creditCode = incomeCode;
                    p.confidence = 0.7;
                } else {
                    p.creditCode = defaultAccountService.getCode(orgId, DefaultAccountPurpose.SALES_REVENUE);
                    p.warnings.add("Couldn't tell the income head — booked to "
                            + nameOf(orgId, p.creditCode) + ". Please correct before approving.");
                    p.confidence = 0.4;
                }
            }
        }

        p.narration = buildNarration(outflow, amount, party, purpose, text);
        return p;
    }

    private String buildNarration(boolean outflow, BigDecimal amount, String party,
                                  String purpose, String original) {
        StringBuilder sb = new StringBuilder(outflow ? "Paid " : "Received ");
        sb.append(amount.toPlainString());
        if (party != null) sb.append(outflow ? " to " : " from ").append(party);
        if (purpose != null) sb.append(" for ").append(purpose);
        String n = sb.toString();
        return n.length() > 480 ? n.substring(0, 480) : n;
    }

    /** First monetary token, applying k/lakh/crore multipliers. */
    static BigDecimal extractAmount(String lower) {
        Matcher m = AMOUNT.matcher(lower);
        while (m.find()) {
            String digits = m.group(1).replace(",", "");
            if (digits.isEmpty() || ".".equals(digits)) continue;
            BigDecimal value;
            try {
                value = new BigDecimal(digits);
            } catch (NumberFormatException e) {
                continue;
            }
            if (value.signum() == 0) continue;
            String unit = m.group(2);
            if (unit != null) {
                String u = unit.toLowerCase(Locale.ROOT);
                if (u.equals("k")) value = value.multiply(BigDecimal.valueOf(1_000));
                else if (u.startsWith("lakh") || u.startsWith("lac")) value = value.multiply(BigDecimal.valueOf(100_000));
                else value = value.multiply(BigDecimal.valueOf(10_000_000)); // crore
            }
            return value;
        }
        return null;
    }

    private String instrumentCode(UUID orgId, String lower) {
        if (containsAny(lower, "bank", "neft", "imps", "rtgs", "cheque", "check", "upi",
                "online", "card", "netbanking", "net banking", "transfer", "gpay", "phonepe", "paytm")) {
            return defaultAccountService.getCode(orgId, DefaultAccountPurpose.BANK);
        }
        return defaultAccountService.getCode(orgId, DefaultAccountPurpose.CASH);
    }

    /** Text after "to "/"from ", trimmed before "for"/"against"/"towards". */
    static String extractParty(String original, String lower, String marker) {
        int idx = lower.indexOf(marker);
        if (idx < 0) return null;
        int start = idx + marker.length();
        String rest = original.substring(start);
        String restLower = lower.substring(start);
        int end = rest.length();
        for (String stop : new String[]{" for ", " against ", " towards ", " on ", " via ", " by "}) {
            int s = restLower.indexOf(stop);
            if (s >= 0 && s < end) end = s;
        }
        String party = rest.substring(0, end).trim();
        return party.isEmpty() ? null : party;
    }

    /** Text after "for "/"towards ". */
    static String extractPurpose(String original, String lower) {
        for (String marker : new String[]{" for ", " towards "}) {
            int idx = lower.indexOf(marker);
            if (idx >= 0) {
                String purpose = original.substring(idx + marker.length()).trim();
                // Stop at a trailing party clause if it came after.
                int via = purpose.toLowerCase(Locale.ROOT).indexOf(" to ");
                if (via > 0) purpose = purpose.substring(0, via).trim();
                return purpose.isEmpty() ? null : purpose;
            }
        }
        return null;
    }

    /** Match an account of the given type whose name overlaps the purpose keywords. */
    private String matchAccountByKeywords(UUID orgId, String purpose, String type) {
        if (purpose == null || purpose.isBlank()) return null;
        List<String> words = new ArrayList<>();
        for (String w : purpose.toLowerCase(Locale.ROOT).split("[^a-z0-9]+")) {
            if (w.length() >= 3 && !STOPWORDS.contains(w)) words.add(w);
        }
        if (words.isEmpty()) return null;

        String best = null;
        int bestScore = 0;
        for (Account a : accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)) {
            if (!type.equals(a.getType())) continue;
            String name = a.getName().toLowerCase(Locale.ROOT);
            int score = 0;
            for (String w : words) {
                if (name.contains(w)) score += w.length();
            }
            if (score > bestScore) {
                bestScore = score;
                best = a.getCode();
            }
        }
        return best;
    }

    private String fallbackExpenseCode(UUID orgId) {
        for (Account a : accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)) {
            if ("EXPENSE".equals(a.getType())
                    && a.getName().toLowerCase(Locale.ROOT).contains("miscellaneous")) {
                return a.getCode();
            }
        }
        // Last resort: the purchase-expense default (always seeded).
        return defaultAccountService.getCode(orgId, DefaultAccountPurpose.PURCHASE);
    }

    private static final Set<String> STOPWORDS = Set.of(
            "the", "for", "and", "bill", "payment", "charges", "charge", "expense", "expenses", "fees", "fee");

    // ── Helpers ──────────────────────────────────────────────────────────

    private static boolean containsAny(String haystack, String... needles) {
        for (String n : needles) {
            if (haystack.contains(n)) return true;
        }
        return false;
    }

    private String nameOf(UUID orgId, String code) {
        return accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                .map(Account::getName).orElse(code);
    }

    private EntryDraftResult notDrafted(String message) {
        return new EntryDraftResult(false, null, null, null, null, null, 0d,
                List.of(), List.of(), message);
    }

    private AiSuggestion loadDraftEntrySuggestion(UUID suggestionId, UUID orgId) {
        AiSuggestion s = aiSuggestionRepository.findByIdAndOrgId(suggestionId, orgId)
                .orElseThrow(() -> new BusinessException(
                        "Draft entry not found", "AI_DRAFT_ENTRY_NOT_FOUND", HttpStatus.NOT_FOUND));
        if (!SUGGESTION_TYPE.equals(s.getSuggestionType())) {
            throw new BusinessException("Not a conversational-entry draft",
                    "AI_DRAFT_ENTRY_WRONG_TYPE", HttpStatus.BAD_REQUEST);
        }
        if (!"PENDING".equals(s.getStatus())) {
            throw new BusinessException("This entry was already " + s.getStatus().toLowerCase(Locale.ROOT),
                    "AI_DRAFT_ENTRY_NOT_PENDING", HttpStatus.CONFLICT);
        }
        return s;
    }

    private static double confidenceOf(AiSuggestion s) {
        return s.getConfidence() == null ? 0.6 : s.getConfidence().doubleValue();
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
