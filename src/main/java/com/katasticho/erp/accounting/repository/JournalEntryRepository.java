package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.JournalEntry;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
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

    @Query("SELECT je FROM JournalEntry je WHERE je.orgId = :orgId AND je.effectiveDate BETWEEN :startDate AND :endDate ORDER BY je.effectiveDate DESC")
    Page<JournalEntry> findByOrgIdAndDateRange(UUID orgId, LocalDate startDate, LocalDate endDate, Pageable pageable);

    @Query("""
            SELECT je FROM JournalEntry je WHERE je.orgId = :orgId
            AND (:sourceModule IS NULL OR je.sourceModule = :sourceModule)
            AND (:dateFrom IS NULL OR je.effectiveDate >= :dateFrom)
            AND (:dateTo IS NULL OR je.effectiveDate <= :dateTo)
            AND (:search IS NULL OR LOWER(je.entryNumber) LIKE LOWER(CONCAT('%', :search, '%'))
                 OR LOWER(je.description) LIKE LOWER(CONCAT('%', :search, '%')))
            ORDER BY je.effectiveDate DESC, je.createdAt DESC
            """)
    Page<JournalEntry> findFiltered(UUID orgId, String sourceModule, LocalDate dateFrom, LocalDate dateTo,
                                     String search, Pageable pageable);
}
