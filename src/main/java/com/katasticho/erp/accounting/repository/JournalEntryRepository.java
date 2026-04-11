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

    Page<JournalEntry> findByOrgIdAndStatusOrderByEffectiveDateDesc(UUID orgId, String status, Pageable pageable);

    Page<JournalEntry> findByOrgIdOrderByEffectiveDateDesc(UUID orgId, Pageable pageable);

    @Query("SELECT je FROM JournalEntry je WHERE je.orgId = :orgId AND je.effectiveDate BETWEEN :startDate AND :endDate ORDER BY je.effectiveDate DESC")
    Page<JournalEntry> findByOrgIdAndDateRange(UUID orgId, LocalDate startDate, LocalDate endDate, Pageable pageable);
}
