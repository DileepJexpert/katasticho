package com.katasticho.erp.inventory.consignment.repository;

import com.katasticho.erp.inventory.consignment.entity.ConsignmentStock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ConsignmentStockRepository extends JpaRepository<ConsignmentStock, UUID> {

    List<ConsignmentStock> findByOrgIdAndIsDeletedFalse(UUID orgId);

    List<ConsignmentStock> findByOrgIdAndSupplierIdAndIsDeletedFalse(UUID orgId, UUID supplierId);

    Optional<ConsignmentStock> findByOrgIdAndItemIdAndWarehouseIdAndSupplierIdAndIsDeletedFalse(
            UUID orgId, UUID itemId, UUID warehouseId, UUID supplierId);
}
