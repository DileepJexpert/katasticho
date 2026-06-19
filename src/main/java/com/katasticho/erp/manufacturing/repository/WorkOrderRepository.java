package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.WorkOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WorkOrderRepository extends JpaRepository<WorkOrder, UUID> {

    Optional<WorkOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Shop-floor lookup by the printed/scanned WO number (case-insensitive). */
    Optional<WorkOrder> findByOrgIdAndWorkOrderNumberIgnoreCaseAndIsDeletedFalse(
            UUID orgId, String workOrderNumber);

    Page<WorkOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<WorkOrder> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status, Pageable pageable);

    List<WorkOrder> findByOrgIdAndStatusInAndIsDeletedFalse(UUID orgId, List<String> statuses);

    Page<WorkOrder> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    Page<WorkOrder> findByOrgIdAndPriorityAndIsDeletedFalse(UUID orgId, String priority, Pageable pageable);

    Page<WorkOrder> findByOrgIdAndStatusAndPriorityAndIsDeletedFalse(
            UUID orgId, String status, String priority, Pageable pageable);

    /**
     * Default WO list ordering: URGENT first, then HIGH, NORMAL, LOW —
     * newest first within each band. Used when the caller supplies no
     * explicit sort. Null filters mean "no filter".
     */
    @Query("SELECT w FROM WorkOrder w WHERE w.orgId = :orgId AND w.isDeleted = false " +
            "AND (:status IS NULL OR w.status = :status) " +
            "AND (:priority IS NULL OR w.priority = :priority) " +
            "ORDER BY CASE w.priority WHEN 'URGENT' THEN 0 WHEN 'HIGH' THEN 1 " +
            "WHEN 'LOW' THEN 3 ELSE 2 END, w.createdAt DESC")
    Page<WorkOrder> findForListPriorityFirst(
            @Param("orgId") UUID orgId,
            @Param("status") String status,
            @Param("priority") String priority,
            Pageable pageable);

    List<WorkOrder> findByOrgIdAndIsDeletedFalseAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            UUID orgId, Instant from, Instant to);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(w.workOrderNumber, 4) AS int)), 0) FROM WorkOrder w WHERE w.orgId = :orgId")
    int findMaxWorkOrderNumber(UUID orgId);

    /**
     * Dedupe guard for the reorder-point auto-WO sweep — don't spawn a
     * second DRAFT for an FG that already has an open one.
     */
    boolean existsByOrgIdAndFinishedGoodIdAndStatusInAndIsDeletedFalse(
            UUID orgId, UUID finishedGoodId, List<String> statuses);

    /**
     * Child WOs for a sub-assembly tree (tracker #60). Used both to list
     * dependents on the parent WO detail screen and to enforce the
     * "all children complete before parent can issue" gate.
     */
    List<WorkOrder> findByOrgIdAndParentWorkOrderIdAndIsDeletedFalse(
            UUID orgId, UUID parentWorkOrderId);
}
