package com.katasticho.erp.recurring.repository;

import com.katasticho.erp.recurring.entity.RecurringJournal;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RecurringJournalRepository extends JpaRepository<RecurringJournal, UUID> {

    Optional<RecurringJournal> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Pessimistic re-read so concurrent generate-now runs serialise (no double-post). */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from RecurringJournal t where t.id = :id and t.orgId = :orgId and t.isDeleted = false")
    Optional<RecurringJournal> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);

    Page<RecurringJournal> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<RecurringJournal> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    @Query("""
        SELECT r FROM RecurringJournal r
        WHERE r.isDeleted = false
          AND r.status = 'ACTIVE'
          AND r.nextRunDate <= :today
        ORDER BY r.nextRunDate ASC
    """)
    List<RecurringJournal> findDueTemplates(LocalDate today);
}
