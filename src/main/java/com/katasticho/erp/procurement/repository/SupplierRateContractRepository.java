package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.SupplierRateContract;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SupplierRateContractRepository extends JpaRepository<SupplierRateContract, UUID> {

    Optional<SupplierRateContract> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<SupplierRateContract> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, Pageable pageable);

    Page<SupplierRateContract> findByOrgIdAndSupplierContactIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, UUID supplierContactId, Pageable pageable);

    List<SupplierRateContract> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);

    @Query("""
        SELECT c FROM SupplierRateContract c
        WHERE c.orgId = :orgId
          AND c.status = 'ACTIVE'
          AND c.isDeleted = false
          AND c.validUntil IS NOT NULL
          AND c.validUntil < :asOf
    """)
    List<SupplierRateContract> findExpiringActive(UUID orgId, LocalDate asOf);
}
