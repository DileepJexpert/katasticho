package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.SupplyChainAlert;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SupplyChainAlertRepository extends JpaRepository<SupplyChainAlert, UUID> {

    Optional<SupplyChainAlert> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<SupplyChainAlert> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<SupplyChainAlert> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status, Pageable pageable);

    List<SupplyChainAlert> findByOrgIdAndAlertTypeAndStatusAndIsDeletedFalse(UUID orgId, String alertType, String status);

    long countByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);
}
