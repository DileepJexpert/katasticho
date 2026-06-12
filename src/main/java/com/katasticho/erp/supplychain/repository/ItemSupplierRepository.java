package com.katasticho.erp.supplychain.repository;

import com.katasticho.erp.supplychain.entity.ItemSupplier;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ItemSupplierRepository extends JpaRepository<ItemSupplier, UUID> {

    List<ItemSupplier> findByOrgIdAndItemIdAndIsDeletedFalse(UUID orgId, UUID itemId);

    List<ItemSupplier> findByOrgIdAndSupplierIdAndIsDeletedFalse(UUID orgId, UUID supplierId);

    Optional<ItemSupplier> findByOrgIdAndItemIdAndSupplierIdAndIsDeletedFalse(UUID orgId, UUID itemId, UUID supplierId);

    Optional<ItemSupplier> findByOrgIdAndItemIdAndPreferredTrueAndIsDeletedFalse(UUID orgId, UUID itemId);
}
