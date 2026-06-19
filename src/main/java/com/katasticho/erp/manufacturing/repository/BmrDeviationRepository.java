package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.BmrDeviation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BmrDeviationRepository extends JpaRepository<BmrDeviation, UUID> {

    Optional<BmrDeviation> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<BmrDeviation> findByOrgIdAndWorkOrderIdAndIsDeletedFalseOrderByReportedAtAsc(
            UUID orgId, UUID workOrderId);

    List<BmrDeviation> findByOrgIdAndStatusInAndIsDeletedFalseOrderByReportedAtDesc(
            UUID orgId, List<String> statuses);
}
