package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.ItemUnitPrice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ItemUnitPriceRepository extends JpaRepository<ItemUnitPrice, UUID> {

    List<ItemUnitPrice> findByOrgIdAndItemIdAndIsDeletedFalse(UUID orgId, UUID itemId);

    void deleteByOrgIdAndItemId(UUID orgId, UUID itemId);
}
