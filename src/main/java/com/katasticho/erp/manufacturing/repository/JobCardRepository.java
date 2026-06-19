package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.JobCard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JobCardRepository extends JpaRepository<JobCard, UUID> {

    List<JobCard> findByWorkOrderIdAndOrgIdAndIsDeletedFalseOrderBySequenceNumberAsc(UUID workOrderId, UUID orgId);

    Optional<JobCard> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<JobCard> findByOrgIdAndAssignedToAndStatusAndIsDeletedFalse(UUID orgId, UUID assignedTo, String status);

    /**
     * Completed job cards a given app user closed inside a window —
     * feeds the production→payroll bridge (tracker #57). Filters on
     * {@code actualEnd} because that's the wall-clock the worker
     * actually completed the operation; {@code planned_end} could be in
     * any period.
     */
    @Query("""
            SELECT jc FROM JobCard jc
             WHERE jc.orgId       = :orgId
               AND jc.assignedTo  = :assignedTo
               AND jc.status      = 'COMPLETED'
               AND jc.isDeleted   = false
               AND jc.actualEnd  >= :from
               AND jc.actualEnd  <  :to
            """)
    List<JobCard> findCompletedByAssigneeInWindow(@Param("orgId") UUID orgId,
                                                  @Param("assignedTo") UUID assignedTo,
                                                  @Param("from") Instant from,
                                                  @Param("to") Instant to);
}
