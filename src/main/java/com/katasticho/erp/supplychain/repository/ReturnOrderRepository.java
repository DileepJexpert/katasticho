package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.ReturnOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface ReturnOrderRepository extends JpaRepository<ReturnOrder, UUID> {

    Optional<ReturnOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<ReturnOrder> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Page<ReturnOrder> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String status, Pageable pageable);

    Page<ReturnOrder> findByOrgIdAndReturnTypeAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, String returnType, Pageable pageable);

    @Query("SELECT COALESCE(MAX(CAST(SUBSTRING(r.returnNumber, 5) AS int)), 0) FROM ReturnOrder r WHERE r.orgId = :orgId")
    int findMaxReturnSequence(@Param("orgId") UUID orgId);
}
