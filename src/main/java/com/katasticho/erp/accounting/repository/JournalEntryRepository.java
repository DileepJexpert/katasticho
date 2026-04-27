package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.JournalEntry;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

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
}
