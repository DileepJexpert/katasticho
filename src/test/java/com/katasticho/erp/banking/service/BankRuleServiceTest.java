package com.katasticho.erp.banking.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.banking.dto.BankRuleDtos.BankRuleRequest;
import com.katasticho.erp.banking.entity.BankRule;
import com.katasticho.erp.banking.entity.BankTransaction;
import com.katasticho.erp.banking.repository.BankRuleRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BankRuleServiceTest {

    @Mock private BankRuleRepository bankRuleRepository;
    @Mock private AccountRepository accountRepository;

    private BankRuleService service;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        service = new BankRuleService(bankRuleRepository, accountRepository);
        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private BankRule rule(String direction, String narrationOp, String narrationValue,
                          String amountOp, BigDecimal amountValue) {
        return BankRule.builder()
                .name("r").priority(100).active(true)
                .directionFilter(direction).narrationOp(narrationOp).narrationValue(narrationValue)
                .amountOp(amountOp).amountValue(amountValue).accountCode("5230").build();
    }

    private BankTransaction tx(String direction, String narration, BigDecimal amount) {
        return BankTransaction.builder()
                .orgId(orgId).transactionDate(LocalDate.of(2026, 5, 20))
                .amount(amount).direction(direction).narration(narration).status("UNMATCHED").build();
    }

    // ── matches() ───────────────────────────────────────────────────────────

    @Test
    void directionFilter_anyMatchesEither_specificMatchesOnlyThatDirection() {
        assertTrue(service.matches(rule("ANY", "ANY", null, "ANY", null), tx("CREDIT", "x", BigDecimal.TEN)));
        assertTrue(service.matches(rule("DEBIT", "ANY", null, "ANY", null), tx("DEBIT", "x", BigDecimal.TEN)));
        assertFalse(service.matches(rule("DEBIT", "ANY", null, "ANY", null), tx("CREDIT", "x", BigDecimal.TEN)));
    }

    @Test
    void narrationOperators_containsEqualsStartsWithRegex_caseInsensitive() {
        BankTransaction t = tx("DEBIT", "MONTHLY BANK CHARGES 05/2026", new BigDecimal("150"));
        assertTrue(service.matches(rule("ANY", "CONTAINS", "bank charges", "ANY", null), t));
        assertFalse(service.matches(rule("ANY", "CONTAINS", "salary", "ANY", null), t));
        assertTrue(service.matches(rule("ANY", "STARTS_WITH", "monthly", "ANY", null), t));
        assertFalse(service.matches(rule("ANY", "STARTS_WITH", "charges", "ANY", null), t));
        assertTrue(service.matches(rule("ANY", "EQUALS", "monthly bank charges 05/2026", "ANY", null), t));
        assertTrue(service.matches(rule("ANY", "REGEX", "charges\\s+\\d\\d/\\d{4}", "ANY", null), t));
        assertFalse(service.matches(rule("ANY", "REGEX", "^salary", "ANY", null), t));
    }

    @Test
    void amountOperators_eqGtLtGteLte() {
        BankTransaction t = tx("DEBIT", "x", new BigDecimal("150.00"));
        assertTrue(service.matches(rule("ANY", "ANY", null, "EQ", new BigDecimal("150.00")), t));
        assertFalse(service.matches(rule("ANY", "ANY", null, "EQ", new BigDecimal("151")), t));
        assertTrue(service.matches(rule("ANY", "ANY", null, "GT", new BigDecimal("100")), t));
        assertTrue(service.matches(rule("ANY", "ANY", null, "LT", new BigDecimal("200")), t));
        assertTrue(service.matches(rule("ANY", "ANY", null, "GTE", new BigDecimal("150.00")), t));
        assertTrue(service.matches(rule("ANY", "ANY", null, "LTE", new BigDecimal("150.00")), t));
        assertFalse(service.matches(rule("ANY", "ANY", null, "GT", new BigDecimal("150.00")), t));
    }

    @Test
    void allThreeConditionsMustHold() {
        // direction ok + narration ok + amount fails → no match
        BankRule r = rule("DEBIT", "CONTAINS", "charges", "GT", new BigDecimal("500"));
        assertFalse(service.matches(r, tx("DEBIT", "bank charges", new BigDecimal("150"))));
        // all three satisfied
        assertTrue(service.matches(
                rule("DEBIT", "CONTAINS", "charges", "LT", new BigDecimal("500")),
                tx("DEBIT", "bank charges", new BigDecimal("150"))));
    }

    @Test
    void firstMatch_returnsHighestPriorityActiveRule() {
        BankRule a = rule("ANY", "CONTAINS", "salary", "ANY", null);   // won't match
        BankRule b = rule("ANY", "CONTAINS", "charges", "ANY", null);  // matches
        b.setId(UUID.randomUUID());
        when(bankRuleRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByPriorityAscCreatedAtAsc(orgId))
                .thenReturn(List.of(a, b));

        Optional<BankRule> match = service.firstMatch(orgId, tx("DEBIT", "bank charges", BigDecimal.TEN));
        assertTrue(match.isPresent());
        assertSame(b, match.get());
    }

    @Test
    void firstMatch_noneMatch_empty() {
        when(bankRuleRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByPriorityAscCreatedAtAsc(orgId))
                .thenReturn(List.of(rule("ANY", "CONTAINS", "salary", "ANY", null)));
        assertTrue(service.firstMatch(orgId, tx("DEBIT", "bank charges", BigDecimal.TEN)).isEmpty());
    }

    // ── validate() via create() ───────────────────────────────────────────────

    private BankRuleRequest req(String direction, String narrationOp, String narrationValue,
                                String amountOp, BigDecimal amountValue, String accountCode) {
        return new BankRuleRequest("Charges", 100, true, direction, narrationOp, narrationValue,
                amountOp, amountValue, accountCode, null, null, false);
    }

    @Test
    void create_validRule_persistsNormalisedUppercaseOps() {
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5230"))
                .thenReturn(Optional.of(Account.builder().code("5230").name("Bank Charges").type("EXPENSE").build()));
        when(bankRuleRepository.save(any(BankRule.class))).thenAnswer(inv -> {
            BankRule r = inv.getArgument(0);
            r.setId(UUID.randomUUID());
            return r;
        });

        var resp = service.create(req("debit", "contains", "charges", "any", null, "5230"));
        assertEquals("DEBIT", resp.directionFilter());
        assertEquals("CONTAINS", resp.narrationOp());
        assertEquals("ANY", resp.amountOp());
        assertEquals("5230", resp.accountCode());
        assertEquals("Bank Charges", resp.accountName());
    }

    @Test
    void create_unknownAccountCode_throws() {
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "9999")).thenReturn(Optional.empty());
        var ex = assertThrows(BusinessException.class,
                () -> service.create(req("ANY", "CONTAINS", "x", "ANY", null, "9999")));
        assertEquals("BANK_RULE_ACCOUNT_NOT_FOUND", ex.getErrorCode());
    }

    @Test
    void create_badRegex_throws() {
        // account existence is validated after operator checks, so no account stub needed
        var ex = assertThrows(BusinessException.class,
                () -> service.create(req("ANY", "REGEX", "([unclosed", "ANY", null, "5230")));
        assertEquals("BANK_RULE_BAD_REGEX", ex.getErrorCode());
    }

    @Test
    void create_narrationValueRequiredForNonAnyOperator() {
        var ex = assertThrows(BusinessException.class,
                () -> service.create(req("ANY", "CONTAINS", "  ", "ANY", null, "5230")));
        assertEquals("BANK_RULE_NARRATION_VALUE_REQUIRED", ex.getErrorCode());
    }

    @Test
    void create_badDirectionAndAmountOperatorRejected() {
        assertEquals("BANK_RULE_BAD_DIRECTION", assertThrows(BusinessException.class,
                () -> service.create(req("SIDEWAYS", "ANY", null, "ANY", null, "5230"))).getErrorCode());
        assertEquals("BANK_RULE_AMOUNT_VALUE_REQUIRED", assertThrows(BusinessException.class,
                () -> service.create(req("ANY", "ANY", null, "GT", null, "5230"))).getErrorCode());
    }

    @Test
    void create_nameTooLong_throwsCleanValidation() {
        var req = new BankRuleRequest("x".repeat(151), 100, true, "ANY", "ANY", null,
                "ANY", null, "5230", null, null, false);
        var ex = assertThrows(BusinessException.class, () -> service.create(req));
        assertEquals("BANK_RULE_NAME_TOO_LONG", ex.getErrorCode());
    }

    @Test
    void matches_pathologicalRegex_isBoundedNotHanging() {
        // (a+)+$ is catastrophic backtracking; on an unbounded engine a long non-matching
        // input takes exponential time. The step-budget guard makes it return quickly.
        BankRule r = rule("ANY", "REGEX", "(a+)+$", "ANY", null);
        String evil = "a".repeat(60) + "X";
        assertTimeoutPreemptively(java.time.Duration.ofSeconds(3),
                () -> assertFalse(service.matches(r, tx("DEBIT", evil, BigDecimal.TEN))));
    }
}
