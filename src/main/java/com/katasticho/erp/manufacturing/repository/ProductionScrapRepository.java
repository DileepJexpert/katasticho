package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.ProductionScrap;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface ProductionScrapRepository extends JpaRepository<ProductionScrap, UUID> {

    List<ProductionScrap> findByWorkOrderIdAndOrgIdAndIsDeletedFalse(UUID workOrderId, UUID orgId);

    Page<ProductionScrap> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    List<ProductionScrap> findByOrgIdAndIsDeletedFalseAndScrappedAtGreaterThanEqualAndScrappedAtLessThan(
            UUID orgId, Instant from, Instant to);
}
