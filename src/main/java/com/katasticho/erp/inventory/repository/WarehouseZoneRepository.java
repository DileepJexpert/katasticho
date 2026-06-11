package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.WarehouseZone;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WarehouseZoneRepository extends JpaRepository<WarehouseZone, UUID> {

    Optional<WarehouseZone> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<WarehouseZone> findByOrgIdAndWarehouseIdAndIsDeletedFalseOrderByCodeAsc(UUID orgId, UUID warehouseId);

    List<WarehouseZone> findByOrgIdAndZoneTypeAndIsDeletedFalseOrderByCodeAsc(UUID orgId, String zoneType);

    boolean existsByOrgIdAndWarehouseIdAndCodeAndIsDeletedFalse(UUID orgId, UUID warehouseId, String code);
}
