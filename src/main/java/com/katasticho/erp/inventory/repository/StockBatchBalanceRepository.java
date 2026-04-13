package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.StockBatchBalance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockBatchBalanceRepository extends JpaRepository<StockBatchBalance, UUID> {

    Optional<StockBatchBalance> findByOrgIdAndBatchIdAndWarehouseId(
            UUID orgId, UUID batchId, UUID warehouseId);

    List<StockBatchBalance> findByOrgIdAndBatchId(UUID orgId, UUID batchId);

    List<StockBatchBalance> findByOrgIdAndWarehouseId(UUID orgId, UUID warehouseId);
}
