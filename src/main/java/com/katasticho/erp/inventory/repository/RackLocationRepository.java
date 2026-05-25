package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.RackLocation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RackLocationRepository extends JpaRepository<RackLocation, UUID> {
    List<RackLocation> findByOrgIdAndWarehouseIdAndIsDeletedFalseOrderByCodeAsc(UUID orgId, UUID warehouseId);
    Optional<RackLocation> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
    Optional<RackLocation> findByOrgIdAndWarehouseIdAndCodeIgnoreCaseAndIsDeletedFalse(UUID orgId, UUID warehouseId, String code);
}
