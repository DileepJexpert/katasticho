package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.SerialNumber;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SerialNumberRepository extends JpaRepository<SerialNumber, UUID> {

    Optional<SerialNumber> findByOrgIdAndItemIdAndSerialAndIsDeletedFalse(UUID orgId, UUID itemId, String serial);

    List<SerialNumber> findByOrgIdAndItemIdAndStatusAndIsDeletedFalse(UUID orgId, UUID itemId, String status);

    List<SerialNumber> findByOrgIdAndItemIdAndWarehouseIdAndStatusAndIsDeletedFalse(
            UUID orgId, UUID itemId, UUID warehouseId, String status);

    Page<SerialNumber> findByOrgIdAndItemIdAndIsDeletedFalse(UUID orgId, UUID itemId, Pageable pageable);

    long countByOrgIdAndItemIdAndStatusAndIsDeletedFalse(UUID orgId, UUID itemId, String status);

    Optional<SerialNumber> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
