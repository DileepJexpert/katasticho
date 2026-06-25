package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.accounting.repository.JournalLineRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link YearEndCloseService#closeYear}: the closing journal must
 * zero each P&L account, route net income to Retained Earnings (credit on profit,
 * debit on loss), balance by construction, and be idempotent.
 *
 * <p>Real entities are built (not mocked) — the project's lombok.config makes
 * accessors final, so {@code getId()} can't be stubbed.
 */
@ExtendWith(MockitoExtension.class)
class YearEndCloseServiceTest {

    @Mock private OrganisationRepository organisationRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private JournalLineRepository journalLineRepository;
    @Mock private JournalEntryRepository journalEntryRepository;
    @Mock private JournalService journalService;
    @Mock private DefaultAccountService defaultAccountService;

    @InjectMocks private YearEndCloseService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        Organisation org = Organisation.builder().fiscalYearStart(4).build(); // April → FY2025 = 2025-04-01..2026-03-31
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private static BigDecimal bd(long v) {
        return BigDecimal.valueOf(v);
    }

    private Account acct(UUID id, String code, String type) {
        Account a = Account.builder().code(code).type(type).build();
        a.setId(id);
        return a;
    }

    private JournalEntry entry(String number) {
        JournalEntry e = JournalEntry.builder().entryNumber(number).reversed(false).build();
        e.setId(UUID.randomUUID());
        return e;
    }

    private void noPriorClose() {
        when(journalEntryRepository.findBySourceModuleAndSourceIdAndStatus(
                eq("YEAR_END_CLOSE"), any(), eq("POSTED"))).thenReturn(List.of());
    }

    @Test
    void profitCreditsRetainedEarnings() {
        UUID rId = UUID.randomUUID(), eId = UUID.randomUUID();
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(List.of(
                acct(rId, "4100", "REVENUE"),
                acct(eId, "5100", "EXPENSE"),
                acct(UUID.randomUUID(), "1010", "ASSET"))); // non-P&L → skipped
        when(journalLineRepository.computeAccountTotalsForPeriod(eq(orgId), any(), any())).thenReturn(List.of(
                new Object[]{rId, bd(0), bd(1000)},   // revenue: credit balance 1000
                new Object[]{eId, bd(600), bd(0)}));   // expense: debit balance 600
        noPriorClose();
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.RETAINED_EARNINGS)).thenReturn("3020");
        JournalEntry entry = entry("JE-1");
        when(journalService.postJournal(any())).thenReturn(entry);

        var result = service.closeYear(2025);

        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        JournalPostRequest req = cap.getValue();
        assertEquals(LocalDate.of(2026, 3, 31), req.effectiveDate());
        assertEquals("YEAR_END_CLOSE", req.sourceModule());
        assertEquals(YearEndCloseService.closeId(orgId, 2025), req.sourceId());
        assertTrue(req.autoPost());
        assertEquals(3, req.lines().size()); // revenue + expense + RE (asset skipped)

        Map<String, JournalLineRequest> byCode = req.lines().stream()
                .collect(Collectors.toMap(JournalLineRequest::accountCode, l -> l));
        assertEquals(0, byCode.get("4100").debit().compareTo(bd(1000)));  // DR revenue to zero it
        assertEquals(0, byCode.get("4100").credit().compareTo(bd(0)));
        assertEquals(0, byCode.get("5100").credit().compareTo(bd(600)));  // CR expense to zero it
        assertEquals(0, byCode.get("3020").credit().compareTo(bd(400)));  // CR Retained Earnings (profit)
        assertEquals(0, byCode.get("3020").debit().compareTo(bd(0)));

        // double-entry balances
        BigDecimal dr = req.lines().stream().map(JournalLineRequest::debit).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cr = req.lines().stream().map(JournalLineRequest::credit).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, dr.compareTo(cr));

        assertEquals(0, result.netIncome().compareTo(bd(400)));
        assertEquals(2, result.plAccountsClosed());
        assertEquals(entry.getId(), result.journalEntryId());
    }

    @Test
    void lossDebitsRetainedEarnings() {
        UUID rId = UUID.randomUUID(), eId = UUID.randomUUID();
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(List.of(
                acct(rId, "4100", "REVENUE"),
                acct(eId, "5100", "EXPENSE")));
        when(journalLineRepository.computeAccountTotalsForPeriod(eq(orgId), any(), any())).thenReturn(List.of(
                new Object[]{rId, bd(0), bd(500)},    // revenue 500
                new Object[]{eId, bd(800), bd(0)}));   // expense 800 → loss 300
        noPriorClose();
        when(defaultAccountService.getCode(orgId, DefaultAccountPurpose.RETAINED_EARNINGS)).thenReturn("3020");
        when(journalService.postJournal(any())).thenReturn(entry("JE-2"));

        var result = service.closeYear(2025);

        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        Map<String, JournalLineRequest> byCode = cap.getValue().lines().stream()
                .collect(Collectors.toMap(JournalLineRequest::accountCode, l -> l));
        assertEquals(0, byCode.get("3020").debit().compareTo(bd(300)));  // DR Retained Earnings (loss)
        assertEquals(0, byCode.get("3020").credit().compareTo(bd(0)));
        assertEquals(0, result.netIncome().compareTo(bd(-300)));
    }

    @Test
    void secondCloseThrowsAndPostsNothing() {
        when(journalEntryRepository.findBySourceModuleAndSourceIdAndStatus(
                eq("YEAR_END_CLOSE"), any(), eq("POSTED"))).thenReturn(List.of(entry("JE-PRIOR")));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.closeYear(2025));
        assertEquals("YEAR_END_ALREADY_CLOSED", ex.getErrorCode());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void noPlActivityPostsNothing() {
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(acct(UUID.randomUUID(), "4100", "REVENUE")));
        when(journalLineRepository.computeAccountTotalsForPeriod(eq(orgId), any(), any()))
                .thenReturn(List.of()); // no posted lines in the year
        noPriorClose();

        var result = service.closeYear(2025);

        assertNull(result.journalEntryId());
        assertEquals(0, result.plAccountsClosed());
        verify(journalService, never()).postJournal(any());
    }
}
