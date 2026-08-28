package com.katasticho.erp.inventory.subcontracting.repository;

import com.katasticho.erp.inventory.subcontracting.entity.JobWorkOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JobWorkOrderRepository extends JpaRepository<JobWorkOrder, UUID> {

    Optional<JobWorkOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<JobWorkOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    List<JobWorkOrder> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);

    List<JobWorkOrder> findByOrgIdAndJobWorkerIdAndIsDeletedFalse(UUID orgId, UUID jobWorkerId);
}
