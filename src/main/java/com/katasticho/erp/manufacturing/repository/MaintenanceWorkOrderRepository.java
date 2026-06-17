package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.MaintenanceWorkOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MaintenanceWorkOrderRepository extends JpaRepository<MaintenanceWorkOrder, UUID> {

    Optional<MaintenanceWorkOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<MaintenanceWorkOrder> findByOrgIdAndIsDeletedFalseOrderByReportedAtDesc(UUID orgId);

    List<MaintenanceWorkOrder> findByOrgIdAndStatusAndIsDeletedFalseOrderByReportedAtDesc(
            UUID orgId, String status);

    List<MaintenanceWorkOrder> findByOrgIdAndWorkstationIdAndIsDeletedFalseOrderByReportedAtDesc(
            UUID orgId, UUID workstationId);

    /**
     * Completed maintenance WOs in a date range, used by the downtime report.
     * Filtered by completedAt to align downtime with the period the equipment
     * was actually out, not when the issue was first reported.
     */
    List<MaintenanceWorkOrder> findByOrgIdAndStatusAndCompletedAtBetweenAndIsDeletedFalseOrderByCompletedAtAsc(
            UUID orgId, String status, Instant from, Instant to);

    /** Highest mwo_number seen for this org — used to generate the next sequence. */
    Optional<MaintenanceWorkOrder> findTopByOrgIdAndMwoNumberStartingWithOrderByMwoNumberDesc(
            UUID orgId, String prefix);
}
