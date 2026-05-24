package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.SalesOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
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

    long countByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);

    @Query("""
        SELECT so FROM SalesOrder so
        WHERE so.orgId = :orgId
          AND so.status IN :statuses
          AND so.isDeleted = false
        ORDER BY so.orderDate ASC
        """)
    List<SalesOrder> findActionableOrders(@Param("orgId") UUID orgId,
                                          @Param("statuses") List<String> statuses,
                                          Pageable pageable);

    @Query("""
        SELECT COUNT(so) FROM SalesOrder so
        WHERE so.orgId = :orgId
          AND so.status IN ('CONFIRMED','BACKORDER')
          AND so.isDeleted = false
          AND so.orderDate <= :cutoff
        """)
    long countOverdue(@Param("orgId") UUID orgId, @Param("cutoff") LocalDate cutoff);
}
