package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.JobWorkOrder;
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
public interface JobWorkOrderRepository extends JpaRepository<JobWorkOrder, UUID> {

    Optional<JobWorkOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<JobWorkOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<JobWorkOrder> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status, Pageable pageable);

    List<JobWorkOrder> findByOrgIdAndGstReturnDeadlineBeforeAndStatusNotAndIsDeletedFalse(
            UUID orgId, LocalDate deadline, String excludeStatus);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(j.jobWorkNumber, 4) AS int)), 0) FROM JobWorkOrder j WHERE j.orgId = :orgId")
    int findMaxJobWorkNumber(UUID orgId);
}
