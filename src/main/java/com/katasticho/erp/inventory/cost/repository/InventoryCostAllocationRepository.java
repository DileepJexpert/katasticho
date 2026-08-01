package com.katasticho.erp.inventory.cost.repository;

import com.katasticho.erp.inventory.cost.entity.InventoryCostAllocation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface InventoryCostAllocationRepository extends JpaRepository<InventoryCostAllocation, UUID> {
    List<InventoryCostAllocation> findByOrgIdAndStockMovementIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID stockMovementId);

    List<InventoryCostAllocation> findByOrgIdAndBatchIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID batchId);
}
