package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.*;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.currency.SimpleCurrencyService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
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
class JournalServiceTest {

    @Mock private JournalEntryRepository journalEntryRepository;
    @Mock private JournalLineRepository journalLineRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private EntryNumberSequenceRepository sequenceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private AuditService auditService;

    private JournalService journalService;

    private UUID orgId;
    private UUID userId;
    private Account cashAccount;
    private Account revenueAccount;

    @BeforeEach
    void setUp() {
        journalService = new JournalService(
                journalEntryRepository, journalLineRepository, accountRepository,
                sequenceRepository, organisationRepository, new SimpleCurrencyService(), auditService);

        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        cashAccount = Account.builder().code("1010").name("Cash").type("ASSET").build();
        cashAccount.setId(UUID.randomUUID());
        cashAccount.setOrgId(orgId);

        revenueAccount = Account.builder().code("4010").name("Sales Revenue").type("REVENUE").build();
        revenueAccount.setId(UUID.randomUUID());
        revenueAccount.setOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // T-ACCT-01: postJournal() rejects imbalanced entry
    @Test
    void shouldRejectImbalancedEntry() {
        var org = Organisation.builder().name("Test").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "1010")).thenReturn(Optional.of(cashAccount));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "4010")).thenReturn(Optional.of(revenueAccount));

        var request = new JournalPostRequest(
                LocalDate.now(), "Test", "MANUAL", null,
                List.of(
                        new JournalLineRequest("1010", new BigDecimal("1000"), BigDecimal.ZERO, "Cash in", null, null),
                        new JournalLineRequest("4010", BigDecimal.ZERO, new BigDecimal("500"), "Revenue", null, null)
                ), true);

        BusinessException ex = assertThrows(BusinessException.class, () -> journalService.postJournal(request));
        assertEquals("ACCT_JOURNAL_IMBALANCE", ex.getErrorCode());
    }

    // T-ACCT-01b: postJournal() rejects zero-amount entry
    @Test
    void shouldRejectZeroAmountEntry() {
        var org = Organisation.builder().name("Test").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "1010")).thenReturn(Optional.of(cashAccount));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "4010")).thenReturn(Optional.of(revenueAccount));

        var request = new JournalPostRequest(
                LocalDate.now(), "Test", "MANUAL", null,
                List.of(
                        new JournalLineRequest("1010", BigDecimal.ZERO, BigDecimal.ZERO, null, null, null),
                        new JournalLineRequest("4010", BigDecimal.ZERO, BigDecimal.ZERO, null, null, null)
                ), true);

        BusinessException ex = assertThrows(BusinessException.class, () -> journalService.postJournal(request));
        assertEquals("ACCT_JOURNAL_ZERO", ex.getErrorCode());
    }

    // T-ACCT-01c: postJournal() accepts balanced entry
    @Test
    void shouldAcceptBalancedEntry() {
        var org = Organisation.builder().name("Test").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "1010")).thenReturn(Optional.of(cashAccount));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "4010")).thenReturn(Optional.of(revenueAccount));
        when(sequenceRepository.findByOrgIdAndYear(eq(orgId), anyInt())).thenReturn(Optional.empty());
        when(sequenceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(journalEntryRepository.save(any(JournalEntry.class))).thenAnswer(inv -> {
            JournalEntry entry = inv.getArgument(0);
            if (entry.getId() == null) entry.setId(UUID.randomUUID());
            return entry;
        });

        var request = new JournalPostRequest(
                LocalDate.now(), "Cash sale", "MANUAL", null,
                List.of(
                        new JournalLineRequest("1010", new BigDecimal("1000"), BigDecimal.ZERO, "Cash in", null, null),
                        new JournalLineRequest("4010", BigDecimal.ZERO, new BigDecimal("1000"), "Revenue", null, null)
                ), true);

        JournalEntry result = journalService.postJournal(request);

        assertNotNull(result);
        assertEquals("POSTED", result.getStatus());
        assertEquals(2, result.getLines().size());
        assertTrue(result.getEntryNumber().startsWith("JE-"));
    }

    // T-ACCT-02: POSTED entry rejects direct status change (tested via reverseEntry flow)
    @Test
    void shouldNotReverseAlreadyReversedEntry() {
        var org = Organisation.builder().name("Test").build();
        org.setId(orgId);

        JournalEntry posted = JournalEntry.builder()
                .orgId(orgId).entryNumber("JE-2026-000001").effectiveDate(LocalDate.now())
                .sourceModule("MANUAL").status("POSTED").reversed(true)
                .periodYear(2026).periodMonth(4).createdBy(userId)
                .build();
        posted.setId(UUID.randomUUID());

        when(journalEntryRepository.findByIdAndOrgId(posted.getId(), orgId)).thenReturn(Optional.of(posted));

        BusinessException ex = assertThrows(BusinessException.class, () -> journalService.reverseEntry(posted.getId()));
        assertEquals("ACCT_ENTRY_ALREADY_REVERSED", ex.getErrorCode());
    }

    // T-ACCT-03: Reversal creates correct mirror entry
    @Test
    void shouldCreateCorrectReversalEntry() {
        var org = Organisation.builder().name("Test").build();
        org.setId(orgId);

        JournalEntry original = JournalEntry.builder()
                .orgId(orgId).entryNumber("JE-2026-000001").effectiveDate(LocalDate.now())
                .description("Original entry").sourceModule("MANUAL").status("POSTED")
                .periodYear(2026).periodMonth(4).createdBy(userId)
                .build();
        original.setId(UUID.randomUUID());

        // Add lines to original
        var line1 = com.katasticho.erp.accounting.entity.JournalLine.builder()
                .accountId(cashAccount.getId()).debit(new BigDecimal("5000")).credit(BigDecimal.ZERO)
                .baseDebit(new BigDecimal("5000")).baseCredit(BigDecimal.ZERO)
                .currency("INR").exchangeRate(BigDecimal.ONE).build();
        line1.setJournalEntry(original);
        var line2 = com.katasticho.erp.accounting.entity.JournalLine.builder()
                .accountId(revenueAccount.getId()).debit(BigDecimal.ZERO).credit(new BigDecimal("5000"))
                .baseDebit(BigDecimal.ZERO).baseCredit(new BigDecimal("5000"))
                .currency("INR").exchangeRate(BigDecimal.ONE).build();
        line2.setJournalEntry(original);
        original.setLines(List.of(line1, line2));

        when(journalEntryRepository.findByIdAndOrgId(original.getId(), orgId)).thenReturn(Optional.of(original));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(sequenceRepository.findByOrgIdAndYear(eq(orgId), anyInt())).thenReturn(Optional.empty());
        when(sequenceRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(journalEntryRepository.save(any(JournalEntry.class))).thenAnswer(inv -> {
            JournalEntry e = inv.getArgument(0);
            if (e.getId() == null) e.setId(UUID.randomUUID());
            return e;
        });

        JournalEntry reversal = journalService.reverseEntry(original.getId());

        assertNotNull(reversal);
        assertTrue(reversal.isReversal());
        assertEquals(original.getId(), reversal.getReversalOfId());
        assertEquals("POSTED", reversal.getStatus());
        assertEquals(2, reversal.getLines().size());

        // Verify debits and credits are swapped
        var revLine1 = reversal.getLines().get(0);
        assertEquals(0, BigDecimal.ZERO.compareTo(revLine1.getDebit()));
        assertEquals(0, new BigDecimal("5000.00").compareTo(revLine1.getCredit()));

        var revLine2 = reversal.getLines().get(1);
        assertEquals(0, new BigDecimal("5000.00").compareTo(revLine2.getDebit()));
        assertEquals(0, BigDecimal.ZERO.compareTo(revLine2.getCredit()));

        // Original should be marked as reversed
        assertTrue(original.isReversed());
    }

    // Test that non-existent account code is rejected
    @Test
    void shouldRejectNonExistentAccountCode() {
        var org = Organisation.builder().name("Test").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "9999")).thenReturn(Optional.empty());

        var request = new JournalPostRequest(
                LocalDate.now(), "Test", "MANUAL", null,
                List.of(
                        new JournalLineRequest("9999", new BigDecimal("100"), BigDecimal.ZERO, null, null, null)
                ), true);

        assertThrows(BusinessException.class, () -> journalService.postJournal(request));
    }

    // T-ACCT-04: Account balance computation
    @Test
    void shouldComputeAccountBalance() {
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, cashAccount.getId()))
                .thenReturn(Optional.of(cashAccount));
        when(journalLineRepository.computeRawBalance(cashAccount.getId(), orgId, LocalDate.now()))
                .thenReturn(new BigDecimal("15000.00"));

        BigDecimal balance = journalService.getAccountBalance(cashAccount.getId(), orgId, LocalDate.now());

        // ASSET account: positive means more debits than credits (correct for cash)
        assertEquals(new BigDecimal("15000.00"), balance);
    }

    @Test
    void shouldFlipSignForRevenueAccount() {
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, revenueAccount.getId()))
                .thenReturn(Optional.of(revenueAccount));
        when(journalLineRepository.computeRawBalance(revenueAccount.getId(), orgId, LocalDate.now()))
                .thenReturn(new BigDecimal("-25000.00")); // More credits than debits

        BigDecimal balance = journalService.getAccountBalance(revenueAccount.getId(), orgId, LocalDate.now());

        // REVENUE: flip sign, so -(-25000) = 25000 (positive means revenue earned)
        assertEquals(new BigDecimal("25000.00"), balance);
    }
}
