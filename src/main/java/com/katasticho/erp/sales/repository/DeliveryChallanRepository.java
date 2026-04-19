package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.DeliveryChallan;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DeliveryChallanRepository extends JpaRepository<DeliveryChallan, UUID> {

    Optional<DeliveryChallan> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<DeliveryChallan> findByOrgIdAndIsDeletedFalseOrderByChallanDateDesc(UUID orgId, Pageable pageable);

    Page<DeliveryChallan> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status, Pageable pageable);

    Page<DeliveryChallan> findByOrgIdAndSalesOrderIdAndIsDeletedFalse(UUID orgId, UUID salesOrderId, Pageable pageable);

    List<DeliveryChallan> findBySalesOrderIdAndOrgIdAndIsDeletedFalse(UUID salesOrderId, UUID orgId);

    int countBySalesOrderIdAndIsDeletedFalse(UUID salesOrderId);
}
