package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.JobCard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JobCardRepository extends JpaRepository<JobCard, UUID> {

    List<JobCard> findByWorkOrderIdAndOrgIdAndIsDeletedFalseOrderBySequenceNumberAsc(UUID workOrderId, UUID orgId);

    Optional<JobCard> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<JobCard> findByOrgIdAndAssignedToAndStatusAndIsDeletedFalse(UUID orgId, UUID assignedTo, String status);
}
