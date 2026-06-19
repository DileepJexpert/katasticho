package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.CapaAction;
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
public interface CapaActionRepository extends JpaRepository<CapaAction, UUID> {

    Optional<CapaAction> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<CapaAction> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, Pageable pageable);

    Page<CapaAction> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    List<CapaAction> findByOrgIdAndAssignedToAndIsDeletedFalseOrderByDueDateAsc(
            UUID orgId, UUID assignedTo);

    List<CapaAction> findByOrgIdAndNcrIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID ncrId);

    /**
     * Overdue CAPAs — open or in-progress with a due_date before today.
     * Sorted by due_date ascending (most overdue first) so the inbox
     * surfaces the riskiest items at the top.
     */
    @Query("""
            SELECT c FROM CapaAction c
             WHERE c.orgId      = :orgId
               AND c.isDeleted  = false
               AND c.status    IN ('OPEN', 'IN_PROGRESS')
               AND c.dueDate   IS NOT NULL
               AND c.dueDate    < :today
             ORDER BY c.dueDate ASC
            """)
    List<CapaAction> findOverdue(@Param("orgId") UUID orgId,
                                 @Param("today") LocalDate today);

    @Query("""
            SELECT COALESCE(MAX(CAST(SUBSTRING(c.capaNumber, 11) AS int)), 0)
              FROM CapaAction c
             WHERE c.orgId = :orgId
               AND c.capaNumber LIKE :prefix
            """)
    int findMaxSequenceForYear(@Param("orgId") UUID orgId,
                               @Param("prefix") String prefix);
}
