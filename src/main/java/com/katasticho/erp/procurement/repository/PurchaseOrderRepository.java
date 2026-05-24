package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.PurchaseOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PurchaseOrderRepository extends JpaRepository<PurchaseOrder, UUID> {

    List<PurchaseOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    Optional<PurchaseOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
