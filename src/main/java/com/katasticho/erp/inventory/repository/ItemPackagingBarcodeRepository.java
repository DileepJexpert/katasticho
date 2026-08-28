package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.ItemPackagingBarcode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ItemPackagingBarcodeRepository extends JpaRepository<ItemPackagingBarcode, UUID> {

    Optional<ItemPackagingBarcode> findByOrgIdAndBarcodeAndIsDeletedFalse(UUID orgId, String barcode);

    List<ItemPackagingBarcode> findByOrgIdAndItemIdAndIsDeletedFalseOrderByConversionFactorAsc(UUID orgId, UUID itemId);

    Optional<ItemPackagingBarcode> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<ItemPackagingBarcode> findByOrgIdAndItemIdAndIsDeletedFalseAndIsPrimaryTrue(UUID orgId, UUID itemId);
}
