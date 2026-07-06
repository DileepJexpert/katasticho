package com.katasticho.erp.recurring.repository;

import com.katasticho.erp.recurring.entity.RecurringBill;
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
public interface RecurringBillRepository extends JpaRepository<RecurringBill, UUID> {

    Optional<RecurringBill> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Pessimistic re-read so concurrent generate-now runs serialise (no double-post). */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from RecurringBill t where t.id = :id and t.orgId = :orgId and t.isDeleted = false")
    Optional<RecurringBill> findByIdAndOrgIdForUpdate(UUID id, UUID orgId);

    Page<RecurringBill> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<RecurringBill> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    @Query("""
        SELECT r FROM RecurringBill r
        WHERE r.isDeleted = false
          AND r.status = 'ACTIVE'
          AND r.nextBillDate <= :today
        ORDER BY r.nextBillDate ASC
    """)
    List<RecurringBill> findDueTemplates(LocalDate today);
}
