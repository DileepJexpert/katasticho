package com.katasticho.erp.inventory.subcontracting.repository;

import com.katasticho.erp.inventory.subcontracting.entity.JobWorkIssueLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JobWorkIssueLineRepository extends JpaRepository<JobWorkIssueLine, UUID> {

    List<JobWorkIssueLine> findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(UUID orgId, UUID jobWorkOrderId);

    Optional<JobWorkIssueLine> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<JobWorkIssueLine> findByOrgIdAndChallanDateBetweenAndIsDeletedFalse(
            UUID orgId, LocalDate startDate, LocalDate endDate);
}
