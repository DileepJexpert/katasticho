package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.PlannedOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PlannedOrderRepository extends JpaRepository<PlannedOrder, UUID> {

    Optional<PlannedOrder> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<PlannedOrder> findByOrgIdAndMrpRunIdAndIsDeletedFalse(UUID orgId, UUID mrpRunId);

    List<PlannedOrder> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);
}
