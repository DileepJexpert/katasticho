package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.SalesOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SalesOrderRepository extends JpaRepository<SalesOrder, UUID> {

    Optional<SalesOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<SalesOrder> findByOrgIdAndIsDeletedFalseOrderByOrderDateDesc(UUID orgId, Pageable pageable);

    Page<SalesOrder> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status, Pageable pageable);

    Page<SalesOrder> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId, Pageable pageable);

    Page<SalesOrder> findByOrgIdAndBranchIdAndIsDeletedFalse(UUID orgId, UUID branchId, Pageable pageable);

    List<SalesOrder> findByEstimateIdAndIsDeletedFalse(UUID estimateId);
}
