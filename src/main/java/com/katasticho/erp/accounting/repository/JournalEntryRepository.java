package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.JournalEntry;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JournalEntryRepository extends JpaRepository<JournalEntry, UUID> {

    Optional<JournalEntry> findByIdAndOrgId(UUID id, UUID orgId);

    /**
     * Single-entry fetch with lines eagerly loaded — used by detail screens
     * to avoid LazyInitializationException when toResponse iterates lines
     * outside the transaction (OSIV is disabled).
     */
    @Query("SELECT je FROM JournalEntry je LEFT JOIN FETCH je.lines WHERE je.id = :id AND je.orgId = :orgId")
    Optional<JournalEntry> findByIdAndOrgIdWithLines(UUID id, UUID orgId);

    Page<JournalEntry> findByOrgIdAndStatusOrderByEffectiveDateDesc(UUID orgId, String status, Pageable pageable);

    Page<JournalEntry> findByOrgIdOrderByEffectiveDateDesc(UUID orgId, Pageable pageable);

    @Query(value = """
            SELECT * FROM journal_entry je
            WHERE je.org_id = CAST(:orgId AS uuid)
              AND (CAST(:sourceModule AS text) IS NULL OR je.source_module = :sourceModule)
              AND (CAST(:dateFrom AS text) IS NULL OR je.effective_date >= CAST(:dateFrom AS date))
              AND (CAST(:dateTo AS text) IS NULL OR je.effective_date <= CAST(:dateTo AS date))
              AND (CAST(:search AS text) IS NULL
                   OR LOWER(je.entry_number) LIKE LOWER(CONCAT('%', :search, '%'))
                   OR LOWER(je.description) LIKE LOWER(CONCAT('%', :search, '%')))
            ORDER BY je.effective_date DESC, je.created_at DESC
            """,
            countQuery = """
            SELECT COUNT(*) FROM journal_entry je
            WHERE je.org_id = CAST(:orgId AS uuid)
              AND (CAST(:sourceModule AS text) IS NULL OR je.source_module = :sourceModule)
              AND (CAST(:dateFrom AS text) IS NULL OR je.effective_date >= CAST(:dateFrom AS date))
              AND (CAST(:dateTo AS text) IS NULL OR je.effective_date <= CAST(:dateTo AS date))
              AND (CAST(:search AS text) IS NULL
                   OR LOWER(je.entry_number) LIKE LOWER(CONCAT('%', :search, '%'))
                   OR LOWER(je.description) LIKE LOWER(CONCAT('%', :search, '%')))
            """,
            nativeQuery = true)
    Page<JournalEntry> findFiltered(@Param("orgId") String orgId,
                                    @Param("sourceModule") String sourceModule,
                                    @Param("dateFrom") String dateFrom,
                                    @Param("dateTo") String dateTo,
                                    @Param("search") String search,
                                    Pageable pageable);

    List<JournalEntry> findByOrgIdAndEffectiveDateBetweenOrderByEffectiveDateDescCreatedAtDesc(
            UUID orgId, LocalDate from, LocalDate to);

    /**
     * Posted entries with lines eagerly loaded, chronological — for the Tally
     * XML voucher export ("CA Bridge"). Excludes reversed/reversal noise is the
     * caller's choice; this returns all POSTED entries in the window.
     */
    @Query("SELECT DISTINCT je FROM JournalEntry je LEFT JOIN FETCH je.lines "
            + "WHERE je.orgId = :orgId AND je.status = 'POSTED' "
            + "AND je.effectiveDate BETWEEN :from AND :to "
            + "ORDER BY je.effectiveDate ASC, je.createdAt ASC")
    List<JournalEntry> findPostedWithLinesInRange(
            @Param("orgId") UUID orgId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    long countByOrgIdAndStatusAndCreatedAtBefore(UUID orgId, String status, java.time.Instant before);

    /** Post-dated DRAFT vouchers whose date has arrived — the daily job posts them. */
    List<JournalEntry> findByStatusAndPostDatedTrueAndEffectiveDateLessThanEqual(
            String status, LocalDate asOfDate);

    /**
     * Walked on GRN cancel so the provisional-COGS reconciliation journal(s)
     * posted against this GRN can be reversed. POSTED-only filter avoids
     * re-reversing an entry that was already wound back.
     */
    List<JournalEntry> findBySourceModuleAndSourceIdAndStatus(
            String sourceModule, UUID sourceId, String status);
}
