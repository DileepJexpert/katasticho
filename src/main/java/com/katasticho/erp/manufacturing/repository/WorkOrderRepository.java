package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.WorkOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WorkOrderRepository extends JpaRepository<WorkOrder, UUID> {

    Optional<WorkOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<WorkOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<WorkOrder> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status, Pageable pageable);

    List<WorkOrder> findByOrgIdAndStatusInAndIsDeletedFalse(UUID orgId, List<String> statuses);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(w.workOrderNumber, 4) AS int)), 0) FROM WorkOrder w WHERE w.orgId = :orgId")
    int findMaxWorkOrderNumber(UUID orgId);
}
