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
}
