package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.PurchaseRequisition;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface PurchaseRequisitionRepository extends JpaRepository<PurchaseRequisition, UUID> {

    Optional<PurchaseRequisition> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<PurchaseRequisition> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<PurchaseRequisition> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status, Pageable pageable);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(pr.requisitionNumber, 4) AS int)), 0) FROM PurchaseRequisition pr WHERE pr.orgId = :orgId")
    int findMaxRequisitionSequence(@Param("orgId") UUID orgId);
}
