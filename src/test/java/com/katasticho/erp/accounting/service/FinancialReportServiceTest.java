package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.report.*;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.entity.JournalLine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalLineRepository;
import com.katasticho.erp.common.context.TenantContext;
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
class FinancialReportServiceTest {

    @Mock private JournalLineRepository journalLineRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private OrganisationRepository organisationRepository;

    private FinancialReportService reportService;
    private UUID orgId;
    private Organisation org;

    // Accounts
    private Account cashAccount;
    private Account arAccount;
    private Account apAccount;
    private Account capitalAccount;
    private Account salesRevenue;
    private Account cogsExpense;
    private Account rentExpense;

    @BeforeEach
    void setUp() {
        reportService = new FinancialReportService(journalLineRepository, accountRepository, organisationRepository);

        orgId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        org = Organisation.builder().name("Test Corp").baseCurrency("INR").build();
        org.setId(orgId);

        cashAccount = buildAccount("1010", "Cash", "ASSET");
        arAccount = buildAccount("1200", "Accounts Receivable", "ASSET");
        apAccount = buildAccount("2010", "Accounts Payable", "LIABILITY");
        capitalAccount = buildAccount("3010", "Owner Capital", "EQUITY");
        salesRevenue = buildAccount("4010", "Sales Revenue", "REVENUE");
        cogsExpense = buildAccount("5010", "Cost of Goods Sold", "EXPENSE");
        rentExpense = buildAccount("5020", "Rent Expense", "EXPENSE");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // T-RPT-01: Trial Balance must balance (SUM debit = SUM credit)
    @Test
    void shouldGenerateBalancedTrialBalance() {
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(cashAccount, arAccount, apAccount, capitalAccount, salesRevenue, cogsExpense));

        // Simulated journal data:
        // Cash DR 50000, AR DR 20000, AP CR 15000, Capital CR 30000, Revenue CR 35000, COGS DR 10000
        when(journalLineRepository.computeTrialBalanceData(eq(orgId), any(LocalDate.class)))
                .thenReturn(List.of(
                        new Object[]{cashAccount.getId(), new BigDecimal("50000.00"), BigDecimal.ZERO},
                        new Object[]{arAccount.getId(), new BigDecimal("20000.00"), BigDecimal.ZERO},
                        new Object[]{apAccount.getId(), BigDecimal.ZERO, new BigDecimal("15000.00")},
                        new Object[]{capitalAccount.getId(), BigDecimal.ZERO, new BigDecimal("30000.00")},
                        new Object[]{salesRevenue.getId(), BigDecimal.ZERO, new BigDecimal("35000.00")},
                        new Object[]{cogsExpense.getId(), new BigDecimal("10000.00"), BigDecimal.ZERO}
                ));

        TrialBalanceResponse tb = reportService.generateTrialBalance(LocalDate.now());

        assertNotNull(tb);
        assertTrue(tb.isBalanced(), "Trial balance must always balance");
        assertEquals(0, tb.totalDebit().compareTo(tb.totalCredit()));
        assertEquals(6, tb.lines().size());

        // Total debits: 50000 + 20000 + 10000 = 80000
        assertEquals(0, new BigDecimal("80000.00").compareTo(tb.totalDebit()));
        // Total credits: 15000 + 30000 + 35000 = 80000
        assertEquals(0, new BigDecimal("80000.00").compareTo(tb.totalCredit()));
    }

    // T-RPT-02: P&L correctly calculates net profit
    @Test
    void shouldGenerateCorrectProfitLoss() {
        LocalDate start = LocalDate.of(2026, 4, 1);
        LocalDate end = LocalDate.of(2026, 4, 30);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(cashAccount, salesRevenue, cogsExpense, rentExpense));

        // Revenue: 50000 (credit-normal, raw = -50000)
        // COGS: 20000 (debit-normal, raw = 20000)
        // Rent: 8000 (debit-normal, raw = 8000)
        when(journalLineRepository.computeAccountTotalsForPeriod(eq(orgId), eq(start), eq(end)))
                .thenReturn(List.of(
                        new Object[]{salesRevenue.getId(), BigDecimal.ZERO, new BigDecimal("50000.00")},
                        new Object[]{cogsExpense.getId(), new BigDecimal("20000.00"), BigDecimal.ZERO},
                        new Object[]{rentExpense.getId(), new BigDecimal("8000.00"), BigDecimal.ZERO}
                ));

        ProfitLossResponse pl = reportService.generateProfitLoss(start, end);

        assertNotNull(pl);
        assertEquals(0, new BigDecimal("50000.00").compareTo(pl.totalRevenue()));
        assertEquals(0, new BigDecimal("28000.00").compareTo(pl.totalExpenses()));
        assertEquals(0, new BigDecimal("22000.00").compareTo(pl.netProfit()));

        assertEquals(1, pl.revenueAccounts().size());
        assertEquals(2, pl.expenseAccounts().size());
        assertEquals("4010", pl.revenueAccounts().get(0).accountCode());
    }

    // T-RPT-02b: P&L with net loss
    @Test
    void shouldShowNetLossWhenExpensesExceedRevenue() {
        LocalDate start = LocalDate.of(2026, 4, 1);
        LocalDate end = LocalDate.of(2026, 4, 30);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(salesRevenue, cogsExpense, rentExpense));

        when(journalLineRepository.computeAccountTotalsForPeriod(eq(orgId), eq(start), eq(end)))
                .thenReturn(List.of(
                        new Object[]{salesRevenue.getId(), BigDecimal.ZERO, new BigDecimal("10000.00")},
                        new Object[]{cogsExpense.getId(), new BigDecimal("15000.00"), BigDecimal.ZERO},
                        new Object[]{rentExpense.getId(), new BigDecimal("8000.00"), BigDecimal.ZERO}
                ));

        ProfitLossResponse pl = reportService.generateProfitLoss(start, end);

        assertEquals(0, new BigDecimal("10000.00").compareTo(pl.totalRevenue()));
        assertEquals(0, new BigDecimal("23000.00").compareTo(pl.totalExpenses()));
        assertTrue(pl.netProfit().compareTo(BigDecimal.ZERO) < 0);
        assertEquals(0, new BigDecimal("-13000.00").compareTo(pl.netProfit()));
    }

    // T-RPT-03: Balance Sheet must balance (Assets = Liabilities + Equity)
    @Test
    void shouldGenerateBalancedBalanceSheet() {
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(cashAccount, arAccount, apAccount, capitalAccount, salesRevenue, cogsExpense));

        // Cash: DR 100000, CR 40000 → raw = 60000 (ASSET)
        // AR: DR 30000, CR 10000 → raw = 20000 (ASSET)
        // AP: DR 5000, CR 15000 → raw = -10000 (LIABILITY, flip → 10000)
        // Capital: DR 0, CR 50000 → raw = -50000 (EQUITY, flip → 50000)
        // Revenue: DR 0, CR 35000 → raw = -35000 (contributes to retained earnings → 35000)
        // COGS: DR 15000, CR 0 → raw = 15000 (reduces retained earnings → -15000)
        // Total retained earnings = 35000 - 15000 = 20000
        // Total equity = 50000 + 20000 = 70000
        // Assets = 60000 + 20000 = 80000
        // Liabilities + Equity = 10000 + 70000 = 80000 ✓
        when(journalLineRepository.computeTrialBalanceData(eq(orgId), any(LocalDate.class)))
                .thenReturn(List.of(
                        new Object[]{cashAccount.getId(), new BigDecimal("100000.00"), new BigDecimal("40000.00")},
                        new Object[]{arAccount.getId(), new BigDecimal("30000.00"), new BigDecimal("10000.00")},
                        new Object[]{apAccount.getId(), new BigDecimal("5000.00"), new BigDecimal("15000.00")},
                        new Object[]{capitalAccount.getId(), BigDecimal.ZERO, new BigDecimal("50000.00")},
                        new Object[]{salesRevenue.getId(), BigDecimal.ZERO, new BigDecimal("35000.00")},
                        new Object[]{cogsExpense.getId(), new BigDecimal("15000.00"), BigDecimal.ZERO}
                ));

        BalanceSheetResponse bs = reportService.generateBalanceSheet(LocalDate.now());

        assertNotNull(bs);
        assertTrue(bs.isBalanced(), "Balance sheet must balance: Assets = Liabilities + Equity");

        assertEquals(0, new BigDecimal("80000.00").compareTo(bs.totalAssets()));
        assertEquals(0, new BigDecimal("10000.00").compareTo(bs.totalLiabilities()));
        assertEquals(0, new BigDecimal("70000.00").compareTo(bs.totalEquity()));
        assertEquals(0, new BigDecimal("20000.00").compareTo(bs.retainedEarnings()));

        // Assets = Liabilities + Equity
        assertEquals(0, bs.totalAssets().compareTo(bs.totalLiabilities().add(bs.totalEquity())));

        assertEquals(2, bs.assetAccounts().size());
        assertEquals(1, bs.liabilityAccounts().size());
        assertEquals(1, bs.equityAccounts().size());
    }

    // T-RPT-04: General Ledger with running balance
    @Test
    void shouldGenerateGeneralLedgerWithRunningBalance() {
        LocalDate start = LocalDate.of(2026, 4, 1);
        LocalDate end = LocalDate.of(2026, 4, 30);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, cashAccount.getId()))
                .thenReturn(Optional.of(cashAccount));

        // Opening balance: previous activity before April 1 → raw 25000 (ASSET, keep as is)
        when(journalLineRepository.computeRawBalance(cashAccount.getId(), orgId, start.minusDays(1)))
                .thenReturn(new BigDecimal("25000.00"));

        // Two entries in April:
        JournalEntry je1 = JournalEntry.builder()
                .entryNumber("JE-2026-000001").effectiveDate(LocalDate.of(2026, 4, 5))
                .description("Cash sale").sourceModule("AR").build();
        je1.setId(UUID.randomUUID());

        JournalEntry je2 = JournalEntry.builder()
                .entryNumber("JE-2026-000002").effectiveDate(LocalDate.of(2026, 4, 15))
                .description("Rent payment").sourceModule("MANUAL").build();
        je2.setId(UUID.randomUUID());

        JournalLine line1 = JournalLine.builder()
                .accountId(cashAccount.getId())
                .description("Cash received")
                .baseDebit(new BigDecimal("10000.00")).baseCredit(BigDecimal.ZERO)
                .build();
        line1.setJournalEntry(je1);

        JournalLine line2 = JournalLine.builder()
                .accountId(cashAccount.getId())
                .description("Rent paid")
                .baseDebit(BigDecimal.ZERO).baseCredit(new BigDecimal("8000.00"))
                .build();
        line2.setJournalEntry(je2);

        when(journalLineRepository.findByAccountAndPeriod(cashAccount.getId(), orgId, start, end))
                .thenReturn(List.of(line1, line2));

        GeneralLedgerResponse gl = reportService.generateGeneralLedger(cashAccount.getId(), start, end);

        assertNotNull(gl);
        assertEquals("1010", gl.accountCode());
        assertEquals("Cash", gl.accountName());
        assertEquals("ASSET", gl.accountType());

        // Opening balance: 25000
        assertEquals(0, new BigDecimal("25000.00").compareTo(gl.openingBalance()));

        // 2 entries
        assertEquals(2, gl.entries().size());

        // Entry 1: DR 10000, running = 25000 + 10000 = 35000
        assertEquals(0, new BigDecimal("10000.00").compareTo(gl.entries().get(0).debit()));
        assertEquals(0, new BigDecimal("35000.00").compareTo(gl.entries().get(0).runningBalance()));

        // Entry 2: CR 8000, running = 35000 - 8000 = 27000
        assertEquals(0, new BigDecimal("8000.00").compareTo(gl.entries().get(1).credit()));
        assertEquals(0, new BigDecimal("27000.00").compareTo(gl.entries().get(1).runningBalance()));

        // Closing balance
        assertEquals(0, new BigDecimal("27000.00").compareTo(gl.closingBalance()));

        // Totals
        assertEquals(0, new BigDecimal("10000.00").compareTo(gl.totalDebit()));
        assertEquals(0, new BigDecimal("8000.00").compareTo(gl.totalCredit()));
    }

    // T-RPT-04b: General Ledger for credit-normal account (Revenue)
    @Test
    void shouldComputeRunningBalanceForCreditNormalAccount() {
        LocalDate start = LocalDate.of(2026, 4, 1);
        LocalDate end = LocalDate.of(2026, 4, 30);

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, salesRevenue.getId()))
                .thenReturn(Optional.of(salesRevenue));

        // Opening: raw = -15000 (Revenue, flip → 15000)
        when(journalLineRepository.computeRawBalance(salesRevenue.getId(), orgId, start.minusDays(1)))
                .thenReturn(new BigDecimal("-15000.00"));

        JournalEntry je = JournalEntry.builder()
                .entryNumber("JE-2026-000010").effectiveDate(LocalDate.of(2026, 4, 10))
                .description("Invoice revenue").sourceModule("AR").build();
        je.setId(UUID.randomUUID());

        // Credit to revenue = 20000
        JournalLine line = JournalLine.builder()
                .accountId(salesRevenue.getId())
                .description("Sales revenue")
                .baseDebit(BigDecimal.ZERO).baseCredit(new BigDecimal("20000.00"))
                .build();
        line.setJournalEntry(je);

        when(journalLineRepository.findByAccountAndPeriod(salesRevenue.getId(), orgId, start, end))
                .thenReturn(List.of(line));

        GeneralLedgerResponse gl = reportService.generateGeneralLedger(salesRevenue.getId(), start, end);

        // Opening: 15000 (credit-normal, so positive)
        assertEquals(0, new BigDecimal("15000.00").compareTo(gl.openingBalance()));

        // After CR 20000: running = 15000 + 20000 = 35000
        assertEquals(0, new BigDecimal("35000.00").compareTo(gl.entries().get(0).runningBalance()));
        assertEquals(0, new BigDecimal("35000.00").compareTo(gl.closingBalance()));
    }

    // T-RPT-01b: Trial balance with no transactions
    @Test
    void shouldReturnEmptyTrialBalanceWithNoTransactions() {
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(cashAccount, salesRevenue));
        when(journalLineRepository.computeTrialBalanceData(eq(orgId), any(LocalDate.class)))
                .thenReturn(List.of());

        TrialBalanceResponse tb = reportService.generateTrialBalance(LocalDate.now());

        assertNotNull(tb);
        assertTrue(tb.isBalanced());
        assertEquals(0, BigDecimal.ZERO.compareTo(tb.totalDebit()));
        assertEquals(0, BigDecimal.ZERO.compareTo(tb.totalCredit()));
        assertTrue(tb.lines().isEmpty());
    }

    private Account buildAccount(String code, String name, String type) {
        Account account = Account.builder().code(code).name(name).type(type).build();
        account.setId(UUID.randomUUID());
        account.setOrgId(orgId);
        return account;
    }
}
