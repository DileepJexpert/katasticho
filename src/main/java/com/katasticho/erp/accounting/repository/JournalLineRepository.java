package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.JournalLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface JournalLineRepository extends JpaRepository<JournalLine, UUID> {

    List<JournalLine> findByJournalEntryId(UUID journalEntryId);

    /**
     * Compute account balance from journal lines (EVENT SOURCING pattern).
     * ALWAYS use base_debit/base_credit for aggregation.
     */
    @Query("""
        SELECT COALESCE(SUM(jl.baseDebit), 0) - COALESCE(SUM(jl.baseCredit), 0)
        FROM JournalLine jl JOIN jl.journalEntry je
        WHERE jl.accountId = :accountId
          AND je.orgId = :orgId
          AND je.status = 'POSTED'
          AND je.effectiveDate <= :asOfDate
    """)
    BigDecimal computeRawBalance(UUID accountId, UUID orgId, LocalDate asOfDate);

    /**
     * Compute raw balance for a date range (for period-specific P&L).
     */
    @Query("""
        SELECT COALESCE(SUM(jl.baseDebit), 0) - COALESCE(SUM(jl.baseCredit), 0)
        FROM JournalLine jl JOIN jl.journalEntry je
        WHERE jl.accountId = :accountId
          AND je.orgId = :orgId
          AND je.status = 'POSTED'
          AND je.effectiveDate BETWEEN :startDate AND :endDate
    """)
    BigDecimal computeRawBalanceForPeriod(UUID accountId, UUID orgId, LocalDate startDate, LocalDate endDate);

    /**
     * Get debit and credit totals per account for trial balance.
     */
    @Query("""
        SELECT jl.accountId,
               COALESCE(SUM(jl.baseDebit), 0),
               COALESCE(SUM(jl.baseCredit), 0)
        FROM JournalLine jl JOIN jl.journalEntry je
        WHERE je.orgId = :orgId
          AND je.status = 'POSTED'
          AND je.effectiveDate <= :asOfDate
        GROUP BY jl.accountId
    """)
    List<Object[]> computeTrialBalanceData(UUID orgId, LocalDate asOfDate);

    /**
     * Get debit/credit totals per account for a date range.
     */
    @Query("""
        SELECT jl.accountId,
               COALESCE(SUM(jl.baseDebit), 0),
               COALESCE(SUM(jl.baseCredit), 0)
        FROM JournalLine jl JOIN jl.journalEntry je
        WHERE je.orgId = :orgId
          AND je.status = 'POSTED'
          AND je.effectiveDate BETWEEN :startDate AND :endDate
        GROUP BY jl.accountId
    """)
    List<Object[]> computeAccountTotalsForPeriod(UUID orgId, LocalDate startDate, LocalDate endDate);

    /**
     * Get all journal lines for an account in a date range (for general ledger).
     */
    @Query("""
        SELECT jl FROM JournalLine jl JOIN FETCH jl.journalEntry je
        WHERE jl.accountId = :accountId
          AND je.orgId = :orgId
          AND je.status = 'POSTED'
          AND je.effectiveDate BETWEEN :startDate AND :endDate
        ORDER BY je.effectiveDate, je.entryNumber
    """)
    List<JournalLine> findByAccountAndPeriod(UUID accountId, UUID orgId, LocalDate startDate, LocalDate endDate);

    /**
     * Does this account have any POSTED journal lines? Used to block deletion
     * of accounts that have been involved in transactions.
     */
    @Query("""
        SELECT CASE WHEN COUNT(jl) > 0 THEN true ELSE false END
        FROM JournalLine jl JOIN jl.journalEntry je
        WHERE jl.accountId = :accountId
          AND je.orgId = :orgId
          AND je.status = 'POSTED'
    """)
    boolean existsByAccountAndPosted(UUID accountId, UUID orgId);

    /**
     * Distinct set of account ids that have at least one POSTED line (org scope).
     * Used to mark `isInvolvedInTransaction` on account list responses without N+1.
     */
    @Query("""
        SELECT DISTINCT jl.accountId
        FROM JournalLine jl JOIN jl.journalEntry je
        WHERE je.orgId = :orgId
          AND je.status = 'POSTED'
    """)
    List<UUID> findAccountIdsWithTransactions(UUID orgId);

    /**
     * All posted journal lines for an account, newest first. Used by the
     * per-account transaction history endpoint.
     */
    @Query("""
        SELECT jl FROM JournalLine jl JOIN FETCH jl.journalEntry je
        WHERE jl.accountId = :accountId
          AND je.orgId = :orgId
          AND je.status = 'POSTED'
        ORDER BY je.effectiveDate DESC, je.entryNumber DESC
    """)
    List<JournalLine> findByAccountNewestFirst(UUID accountId, UUID orgId);
}
