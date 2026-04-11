package com.katasticho.erp.accounting.service;

import com.katasticho.erp.accounting.dto.report.*;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalLine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalLineRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Financial reports computed ENTIRELY from journal_line (event sourcing).
 * NEVER uses cached period_balance — that table is for performance optimization only.
 *
 * All amounts use base_debit/base_credit (multi-currency safe).
 * Sign convention:
 *   - ASSET/EXPENSE: positive = more debits than credits (debit-normal)
 *   - LIABILITY/EQUITY/REVENUE: flip sign (credit-normal)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FinancialReportService {

    private final JournalLineRepository journalLineRepository;
    private final AccountRepository accountRepository;
    private final OrganisationRepository organisationRepository;

    /**
     * Trial Balance: lists every account with its debit/credit totals.
     * SUM(debit column) must equal SUM(credit column) — the double-entry invariant.
     */
    public TrialBalanceResponse generateTrialBalance(LocalDate asOfDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<Account> accounts = accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId);
        Map<UUID, Account> accountMap = accounts.stream()
                .collect(Collectors.toMap(Account::getId, a -> a));

        List<Object[]> rawData = journalLineRepository.computeTrialBalanceData(orgId, asOfDate);

        // Build a map: accountId -> [totalDebit, totalCredit]
        Map<UUID, BigDecimal[]> balanceMap = new HashMap<>();
        for (Object[] row : rawData) {
            UUID accountId = (UUID) row[0];
            BigDecimal totalDebit = (BigDecimal) row[1];
            BigDecimal totalCredit = (BigDecimal) row[2];
            balanceMap.put(accountId, new BigDecimal[]{totalDebit, totalCredit});
        }

        BigDecimal grandTotalDebit = BigDecimal.ZERO;
        BigDecimal grandTotalCredit = BigDecimal.ZERO;
        List<TrialBalanceResponse.TrialBalanceLine> lines = new ArrayList<>();

        for (Account acct : accounts) {
            BigDecimal[] totals = balanceMap.get(acct.getId());
            if (totals == null) continue; // Skip accounts with no transactions

            BigDecimal debit = totals[0];
            BigDecimal credit = totals[1];
            BigDecimal netBalance = debit.subtract(credit);

            // Trial balance shows net balance in appropriate column
            BigDecimal tbDebit, tbCredit;
            if (netBalance.compareTo(BigDecimal.ZERO) >= 0) {
                tbDebit = netBalance;
                tbCredit = BigDecimal.ZERO;
            } else {
                tbDebit = BigDecimal.ZERO;
                tbCredit = netBalance.negate();
            }

            lines.add(new TrialBalanceResponse.TrialBalanceLine(
                    acct.getId(), acct.getCode(), acct.getName(), acct.getType(),
                    tbDebit, tbCredit, netBalance));

            grandTotalDebit = grandTotalDebit.add(tbDebit);
            grandTotalCredit = grandTotalCredit.add(tbCredit);
        }

        boolean isBalanced = grandTotalDebit.compareTo(grandTotalCredit) == 0;

        return new TrialBalanceResponse(
                asOfDate, org.getBaseCurrency(),
                grandTotalDebit, grandTotalCredit,
                isBalanced, lines);
    }

    /**
     * Profit & Loss (Income Statement) for a date range.
     * Revenue - Expenses = Net Profit.
     * Uses period-specific balances (not cumulative).
     */
    public ProfitLossResponse generateProfitLoss(LocalDate startDate, LocalDate endDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<Account> accounts = accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId);
        Map<UUID, Account> accountMap = accounts.stream()
                .collect(Collectors.toMap(Account::getId, a -> a));

        List<Object[]> periodData = journalLineRepository.computeAccountTotalsForPeriod(orgId, startDate, endDate);

        Map<UUID, BigDecimal> rawBalances = new HashMap<>();
        for (Object[] row : periodData) {
            UUID accountId = (UUID) row[0];
            BigDecimal debit = (BigDecimal) row[1];
            BigDecimal credit = (BigDecimal) row[2];
            rawBalances.put(accountId, debit.subtract(credit));
        }

        List<ProfitLossResponse.AccountLine> revenueAccounts = new ArrayList<>();
        List<ProfitLossResponse.AccountLine> expenseAccounts = new ArrayList<>();
        BigDecimal totalRevenue = BigDecimal.ZERO;
        BigDecimal totalExpenses = BigDecimal.ZERO;

        for (Account acct : accounts) {
            BigDecimal rawBalance = rawBalances.getOrDefault(acct.getId(), BigDecimal.ZERO);
            if (rawBalance.compareTo(BigDecimal.ZERO) == 0) continue;

            if ("REVENUE".equals(acct.getType())) {
                // Revenue: credit-normal, flip sign so positive = revenue earned
                BigDecimal amount = rawBalance.negate();
                if (amount.compareTo(BigDecimal.ZERO) != 0) {
                    revenueAccounts.add(new ProfitLossResponse.AccountLine(
                            acct.getId(), acct.getCode(), acct.getName(), amount));
                    totalRevenue = totalRevenue.add(amount);
                }
            } else if ("EXPENSE".equals(acct.getType())) {
                // Expense: debit-normal, positive = expenses incurred
                BigDecimal amount = rawBalance;
                if (amount.compareTo(BigDecimal.ZERO) != 0) {
                    expenseAccounts.add(new ProfitLossResponse.AccountLine(
                            acct.getId(), acct.getCode(), acct.getName(), amount));
                    totalExpenses = totalExpenses.add(amount);
                }
            }
        }

        BigDecimal netProfit = totalRevenue.subtract(totalExpenses);

        return new ProfitLossResponse(
                startDate, endDate, org.getBaseCurrency(),
                totalRevenue, totalExpenses, netProfit,
                revenueAccounts, expenseAccounts);
    }

    /**
     * Balance Sheet as of a specific date.
     * Assets = Liabilities + Equity + Retained Earnings.
     * Retained Earnings = cumulative (Revenue - Expenses) from all prior periods.
     */
    public BalanceSheetResponse generateBalanceSheet(LocalDate asOfDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<Account> accounts = accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId);
        Map<UUID, Account> accountMap = accounts.stream()
                .collect(Collectors.toMap(Account::getId, a -> a));

        List<Object[]> rawData = journalLineRepository.computeTrialBalanceData(orgId, asOfDate);

        Map<UUID, BigDecimal> rawBalances = new HashMap<>();
        for (Object[] row : rawData) {
            UUID accountId = (UUID) row[0];
            BigDecimal debit = (BigDecimal) row[1];
            BigDecimal credit = (BigDecimal) row[2];
            rawBalances.put(accountId, debit.subtract(credit));
        }

        List<BalanceSheetResponse.AccountLine> assetAccounts = new ArrayList<>();
        List<BalanceSheetResponse.AccountLine> liabilityAccounts = new ArrayList<>();
        List<BalanceSheetResponse.AccountLine> equityAccounts = new ArrayList<>();
        BigDecimal totalAssets = BigDecimal.ZERO;
        BigDecimal totalLiabilities = BigDecimal.ZERO;
        BigDecimal totalEquity = BigDecimal.ZERO;
        BigDecimal retainedEarnings = BigDecimal.ZERO;

        for (Account acct : accounts) {
            BigDecimal rawBalance = rawBalances.getOrDefault(acct.getId(), BigDecimal.ZERO);
            if (rawBalance.compareTo(BigDecimal.ZERO) == 0) continue;

            switch (acct.getType()) {
                case "ASSET" -> {
                    // Debit-normal: positive = asset
                    BigDecimal amount = rawBalance;
                    assetAccounts.add(new BalanceSheetResponse.AccountLine(
                            acct.getId(), acct.getCode(), acct.getName(), amount));
                    totalAssets = totalAssets.add(amount);
                }
                case "LIABILITY" -> {
                    // Credit-normal: flip sign
                    BigDecimal amount = rawBalance.negate();
                    liabilityAccounts.add(new BalanceSheetResponse.AccountLine(
                            acct.getId(), acct.getCode(), acct.getName(), amount));
                    totalLiabilities = totalLiabilities.add(amount);
                }
                case "EQUITY" -> {
                    // Credit-normal: flip sign
                    BigDecimal amount = rawBalance.negate();
                    equityAccounts.add(new BalanceSheetResponse.AccountLine(
                            acct.getId(), acct.getCode(), acct.getName(), amount));
                    totalEquity = totalEquity.add(amount);
                }
                case "REVENUE" -> {
                    // Cumulative revenue contributes to retained earnings
                    retainedEarnings = retainedEarnings.add(rawBalance.negate());
                }
                case "EXPENSE" -> {
                    // Cumulative expenses reduce retained earnings
                    retainedEarnings = retainedEarnings.subtract(rawBalance);
                }
            }
        }

        // Add retained earnings to equity
        totalEquity = totalEquity.add(retainedEarnings);

        // Assets should equal Liabilities + Equity (including retained earnings)
        boolean isBalanced = totalAssets.compareTo(totalLiabilities.add(totalEquity)) == 0;

        return new BalanceSheetResponse(
                asOfDate, org.getBaseCurrency(),
                totalAssets, totalLiabilities, totalEquity,
                retainedEarnings, isBalanced,
                assetAccounts, liabilityAccounts, equityAccounts);
    }

    /**
     * General Ledger for a specific account over a date range.
     * Shows every transaction with running balance.
     */
    public GeneralLedgerResponse generateGeneralLedger(UUID accountId, LocalDate startDate, LocalDate endDate) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Account account = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId)
                .orElseThrow(() -> BusinessException.notFound("Account", accountId));

        // Opening balance = all POSTED entries before startDate
        BigDecimal rawOpening = journalLineRepository.computeRawBalance(accountId, orgId, startDate.minusDays(1));
        if (rawOpening == null) rawOpening = BigDecimal.ZERO;

        // Apply sign convention for opening balance
        BigDecimal openingBalance = applySignConvention(rawOpening, account.getType());

        // Get all lines in the period
        List<JournalLine> lines = journalLineRepository.findByAccountAndPeriod(
                accountId, orgId, startDate, endDate);

        BigDecimal totalDebit = BigDecimal.ZERO;
        BigDecimal totalCredit = BigDecimal.ZERO;
        BigDecimal runningBalance = openingBalance;
        List<GeneralLedgerResponse.LedgerEntry> entries = new ArrayList<>();

        for (JournalLine line : lines) {
            BigDecimal debit = line.getBaseDebit();
            BigDecimal credit = line.getBaseCredit();
            totalDebit = totalDebit.add(debit);
            totalCredit = totalCredit.add(credit);

            // Update running balance based on account type
            if (isDebitNormal(account.getType())) {
                runningBalance = runningBalance.add(debit).subtract(credit);
            } else {
                runningBalance = runningBalance.add(credit).subtract(debit);
            }

            entries.add(new GeneralLedgerResponse.LedgerEntry(
                    line.getJournalEntry().getId(),
                    line.getJournalEntry().getEntryNumber(),
                    line.getJournalEntry().getEffectiveDate(),
                    line.getDescription() != null ? line.getDescription() : line.getJournalEntry().getDescription(),
                    line.getJournalEntry().getSourceModule(),
                    debit, credit, runningBalance));
        }

        BigDecimal closingBalance = runningBalance;

        return new GeneralLedgerResponse(
                accountId, account.getCode(), account.getName(), account.getType(),
                startDate, endDate, org.getBaseCurrency(),
                openingBalance, closingBalance,
                totalDebit, totalCredit, entries);
    }

    private BigDecimal applySignConvention(BigDecimal rawBalance, String accountType) {
        if ("LIABILITY".equals(accountType) || "EQUITY".equals(accountType)
                || "REVENUE".equals(accountType)) {
            return rawBalance.negate();
        }
        return rawBalance;
    }

    private boolean isDebitNormal(String accountType) {
        return "ASSET".equals(accountType) || "EXPENSE".equals(accountType);
    }
}
