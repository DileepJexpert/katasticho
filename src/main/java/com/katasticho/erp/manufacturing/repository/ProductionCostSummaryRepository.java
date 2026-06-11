package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.ProductionCostSummary;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ProductionCostSummaryRepository extends JpaRepository<ProductionCostSummary, UUID> {

    Optional<ProductionCostSummary> findByWorkOrderIdAndOrgIdAndIsDeletedFalse(UUID workOrderId, UUID orgId);

    Page<ProductionCostSummary> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    List<ProductionCostSummary> findByOrgIdAndFinishedGoodIdAndIsDeletedFalse(UUID orgId, UUID finishedGoodId);
}
