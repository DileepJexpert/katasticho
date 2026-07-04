package com.katasticho.erp.banking.service;

import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.banking.dto.BankRuleDtos.BankRuleRequest;
import com.katasticho.erp.banking.dto.BankRuleDtos.BankRuleResponse;
import com.katasticho.erp.banking.entity.BankRule;
import com.katasticho.erp.banking.entity.BankTransaction;
import com.katasticho.erp.banking.repository.BankRuleRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * User-defined bank-matching rules. The reconciliation matcher only scores a
 * transaction against outstanding invoices/bills; transactions that are NOT
 * document payments — bank charges, utility auto-debits, interest credits,
 * salary transfers — never match. A bank rule lets an org categorise them: the
 * first ACTIVE rule (by ascending priority) whose direction / narration / amount
 * conditions all hold "wins", and its target GL account is proposed as a
 * high-confidence ACCOUNT match (auto-applied on import when {@code autoApply}).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class BankRuleService {

    private static final Set<String> DIRECTIONS = Set.of("ANY", "CREDIT", "DEBIT");
    private static final Set<String> NARRATION_OPS =
            Set.of("ANY", "CONTAINS", "EQUALS", "STARTS_WITH", "REGEX");
    private static final Set<String> AMOUNT_OPS = Set.of("ANY", "EQ", "GT", "LT", "GTE", "LTE");

    private final BankRuleRepository bankRuleRepository;
    private final AccountRepository accountRepository;

    // ── CRUD ────────────────────────────────────────────────────────────────

    @Transactional
    public BankRuleResponse create(BankRuleRequest req) {
        UUID orgId = requireOrgId();
        validate(orgId, req);
        BankRule rule = BankRule.builder()
                .name(req.name().trim())
                .priority(req.priority() != null ? req.priority() : 100)
                .active(req.active() == null || req.active())
                .directionFilter(up(req.directionFilter(), "ANY"))
                .narrationOp(up(req.narrationOp(), "CONTAINS"))
                .narrationValue(blankToNull(req.narrationValue()))
                .amountOp(up(req.amountOp(), "ANY"))
                .amountValue(req.amountValue())
                .accountCode(req.accountCode().trim())
                .contactId(req.contactId())
                .memo(blankToNull(req.memo()))
                .autoApply(req.autoApply() != null && req.autoApply())
                .build();
        rule.setOrgId(orgId);
        rule.setCreatedBy(TenantContext.getCurrentUserId());
        return toResponse(bankRuleRepository.save(rule), orgId);
    }

    @Transactional
    public BankRuleResponse update(UUID id, BankRuleRequest req) {
        UUID orgId = requireOrgId();
        validate(orgId, req);
        BankRule rule = require(id, orgId);
        rule.setName(req.name().trim());
        rule.setPriority(req.priority() != null ? req.priority() : 100);
        rule.setActive(req.active() == null || req.active());
        rule.setDirectionFilter(up(req.directionFilter(), "ANY"));
        rule.setNarrationOp(up(req.narrationOp(), "CONTAINS"));
        rule.setNarrationValue(blankToNull(req.narrationValue()));
        rule.setAmountOp(up(req.amountOp(), "ANY"));
        rule.setAmountValue(req.amountValue());
        rule.setAccountCode(req.accountCode().trim());
        rule.setContactId(req.contactId());
        rule.setMemo(blankToNull(req.memo()));
        rule.setAutoApply(req.autoApply() != null && req.autoApply());
        return toResponse(bankRuleRepository.save(rule), orgId);
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = requireOrgId();
        BankRule rule = require(id, orgId);
        rule.setDeleted(true);
        bankRuleRepository.save(rule);
    }

    @Transactional(readOnly = true)
    public BankRuleResponse get(UUID id) {
        UUID orgId = requireOrgId();
        return toResponse(require(id, orgId), orgId);
    }

    @Transactional(readOnly = true)
    public List<BankRuleResponse> list() {
        UUID orgId = requireOrgId();
        return bankRuleRepository.findByOrgIdAndIsDeletedFalseOrderByPriorityAscCreatedAtAsc(orgId)
                .stream().map(r -> toResponse(r, orgId)).toList();
    }

    // ── Matching (called by BankReconciliationService within its own tx) ──────

    /** First active rule (by ascending priority, then creation order) that matches. */
    public Optional<BankRule> firstMatch(UUID orgId, BankTransaction tx) {
        for (BankRule rule : bankRuleRepository
                .findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByPriorityAscCreatedAtAsc(orgId)) {
            if (matches(rule, tx)) {
                return Optional.of(rule);
            }
        }
        return Optional.empty();
    }

    /** Org-scoped rule lookup (used to resolve the memo at accept time). */
    public Optional<BankRule> findEntity(UUID orgId, UUID ruleId) {
        if (ruleId == null) return Optional.empty();
        return bankRuleRepository.findByIdAndOrgIdAndIsDeletedFalse(ruleId, orgId);
    }

    /** All three conditions (direction, narration, amount) must hold. Package-private for tests. */
    boolean matches(BankRule rule, BankTransaction tx) {
        return directionMatches(rule, tx.getDirection())
                && narrationMatches(rule, tx.getNarration())
                && amountMatches(rule, tx.getAmount());
    }

    private boolean directionMatches(BankRule rule, String direction) {
        String dir = up(rule.getDirectionFilter(), "ANY");
        return "ANY".equals(dir) || (direction != null && dir.equalsIgnoreCase(direction));
    }

    private boolean narrationMatches(BankRule rule, String narration) {
        String op = up(rule.getNarrationOp(), "CONTAINS");
        if ("ANY".equals(op)) return true;
        String value = rule.getNarrationValue();
        if (value == null || value.isBlank()) return true; // no value → nothing to test against
        String n = narration == null ? "" : narration.toLowerCase(Locale.ROOT);
        String v = value.toLowerCase(Locale.ROOT);
        return switch (op) {
            case "CONTAINS" -> n.contains(v);
            case "EQUALS" -> n.equals(v);
            case "STARTS_WITH" -> n.startsWith(v);
            case "REGEX" -> regexFind(value, narration);
            default -> false;
        };
    }

    private boolean regexFind(String pattern, String narration) {
        try {
            String input = narration == null ? "" : narration;
            return Pattern.compile(pattern, Pattern.CASE_INSENSITIVE)
                    .matcher(new BoundedCharSequence(input, REGEX_MAX_STEPS)).find();
        } catch (RuntimeException e) {
            // Invalid regex OR a catastrophic-backtracking pattern that blew the step budget
            // → no match. Never let a rule regex hang the whole statement import.
            return false;
        }
    }

    /** Cap on regex character reads per narration — bounds catastrophic backtracking (ReDoS). */
    private static final int REGEX_MAX_STEPS = 200_000;

    /**
     * A CharSequence that throws once the regex engine has read more than {@code maxSteps}
     * characters. Java's backtracking regex reads characters proportional to the number of
     * match steps, so a pathological pattern like {@code (a+)+$} — which compiles fine and so
     * passes validation — is bounded to O(maxSteps) work instead of exponential; the matcher
     * aborts and {@link #regexFind} treats it as no-match. The step counter is shared across
     * subSequences so the bound holds for the whole match.
     */
    private static final class BoundedCharSequence implements CharSequence {
        private final CharSequence delegate;
        private final int maxSteps;
        private final int[] steps; // shared mutable counter across subSequences

        BoundedCharSequence(CharSequence delegate, int maxSteps) {
            this(delegate, maxSteps, new int[1]);
        }

        private BoundedCharSequence(CharSequence delegate, int maxSteps, int[] steps) {
            this.delegate = delegate;
            this.maxSteps = maxSteps;
            this.steps = steps;
        }

        @Override
        public int length() {
            return delegate.length();
        }

        @Override
        public char charAt(int index) {
            if (++steps[0] > maxSteps) {
                throw new IllegalStateException("regex step budget exceeded");
            }
            return delegate.charAt(index);
        }

        @Override
        public CharSequence subSequence(int start, int end) {
            return new BoundedCharSequence(delegate.subSequence(start, end), maxSteps, steps);
        }

        @Override
        public String toString() {
            return delegate.toString();
        }
    }

    private boolean amountMatches(BankRule rule, BigDecimal amount) {
        String op = up(rule.getAmountOp(), "ANY");
        if ("ANY".equals(op)) return true;
        BigDecimal v = rule.getAmountValue();
        if (v == null) return true;
        if (amount == null) return false;
        int cmp = amount.compareTo(v);
        return switch (op) {
            case "EQ" -> cmp == 0;
            case "GT" -> cmp > 0;
            case "LT" -> cmp < 0;
            case "GTE" -> cmp >= 0;
            case "LTE" -> cmp <= 0;
            default -> false;
        };
    }

    // ── Validation ────────────────────────────────────────────────────────────

    private void validate(UUID orgId, BankRuleRequest req) {
        if (req.name() == null || req.name().isBlank()) {
            throw bad("Rule name is required", "BANK_RULE_NAME_REQUIRED");
        }
        // Length bounds mirror the DB columns (name VARCHAR(150), memo VARCHAR(255)) so an
        // over-length value returns a clean 400 instead of a DataIntegrityViolation → 500.
        if (req.name().trim().length() > 150) {
            throw bad("Rule name must be 150 characters or fewer", "BANK_RULE_NAME_TOO_LONG");
        }
        if (req.memo() != null && req.memo().trim().length() > 255) {
            throw bad("Memo must be 255 characters or fewer", "BANK_RULE_MEMO_TOO_LONG");
        }
        String dir = up(req.directionFilter(), "ANY");
        if (!DIRECTIONS.contains(dir)) {
            throw bad("Invalid direction filter: " + req.directionFilter(), "BANK_RULE_BAD_DIRECTION");
        }
        String nop = up(req.narrationOp(), "CONTAINS");
        if (!NARRATION_OPS.contains(nop)) {
            throw bad("Invalid narration operator: " + req.narrationOp(), "BANK_RULE_BAD_NARRATION_OP");
        }
        if (!"ANY".equals(nop) && (req.narrationValue() == null || req.narrationValue().isBlank())) {
            throw bad("Narration value is required for operator " + nop, "BANK_RULE_NARRATION_VALUE_REQUIRED");
        }
        if ("REGEX".equals(nop)) {
            try {
                Pattern.compile(req.narrationValue());
            } catch (RuntimeException e) {
                throw bad("Invalid regular expression: " + e.getMessage(), "BANK_RULE_BAD_REGEX");
            }
        }
        String aop = up(req.amountOp(), "ANY");
        if (!AMOUNT_OPS.contains(aop)) {
            throw bad("Invalid amount operator: " + req.amountOp(), "BANK_RULE_BAD_AMOUNT_OP");
        }
        if (!"ANY".equals(aop) && (req.amountValue() == null || req.amountValue().signum() < 0)) {
            throw bad("A non-negative amount value is required for operator " + aop,
                    "BANK_RULE_AMOUNT_VALUE_REQUIRED");
        }
        if (req.accountCode() == null || req.accountCode().isBlank()) {
            throw bad("Target account code is required", "BANK_RULE_ACCOUNT_REQUIRED");
        }
        accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, req.accountCode().trim())
                .orElseThrow(() -> bad("Account code " + req.accountCode() + " does not exist",
                        "BANK_RULE_ACCOUNT_NOT_FOUND"));
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private BankRuleResponse toResponse(BankRule r, UUID orgId) {
        String accountName = r.getAccountCode() == null ? null
                : accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, r.getAccountCode())
                .map(a -> a.getName()).orElse(null);
        return new BankRuleResponse(
                r.getId(), r.getName(), r.getPriority(), r.isActive(),
                r.getDirectionFilter(), r.getNarrationOp(), r.getNarrationValue(),
                r.getAmountOp(), r.getAmountValue(),
                r.getAccountCode(), accountName,
                r.getContactId(), r.getMemo(), r.isAutoApply());
    }

    private BankRule require(UUID id, UUID orgId) {
        return bankRuleRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("BankRule", id));
    }

    private static String up(String value, String fallback) {
        return (value == null || value.isBlank()) ? fallback : value.trim().toUpperCase(Locale.ROOT);
    }

    private static String blankToNull(String value) {
        return (value == null || value.isBlank()) ? null : value.trim();
    }

    private static BusinessException bad(String message, String code) {
        return new BusinessException(message, code, HttpStatus.BAD_REQUEST);
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
