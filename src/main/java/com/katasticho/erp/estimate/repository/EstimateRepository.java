package com.katasticho.erp.estimate.repository;

import com.katasticho.erp.estimate.entity.Estimate;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface EstimateRepository extends JpaRepository<Estimate, UUID> {

    Optional<Estimate> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Estimate> findByOrgIdAndIsDeletedFalseOrderByEstimateDateDescCreatedAtDesc(
            UUID orgId, Pageable pageable);

    Page<Estimate> findByOrgIdAndStatusAndIsDeletedFalseOrderByEstimateDateDescCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    Page<Estimate> findByOrgIdAndContactIdAndIsDeletedFalseOrderByEstimateDateDescCreatedAtDesc(
            UUID orgId, UUID contactId, Pageable pageable);
}
