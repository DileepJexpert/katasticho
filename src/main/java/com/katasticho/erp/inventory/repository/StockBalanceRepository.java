package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.StockBalance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockBalanceRepository extends JpaRepository<StockBalance, UUID> {

    Optional<StockBalance> findByOrgIdAndItemIdAndWarehouseId(UUID orgId, UUID itemId, UUID warehouseId);

    List<StockBalance> findByOrgIdAndItemId(UUID orgId, UUID itemId);

    List<StockBalance> findByOrgIdAndWarehouseId(UUID orgId, UUID warehouseId);

    /**
     * Items currently at or below their reorder level. Used by the dashboard
     * "low stock" widget.
     */
    @Query("""
            SELECT b FROM StockBalance b, Item i
            WHERE b.orgId = :orgId
              AND b.itemId = i.id
              AND i.isDeleted = false
              AND i.trackInventory = true
              AND i.active = true
              AND b.quantityOnHand <= i.reorderLevel
            ORDER BY b.quantityOnHand ASC
            """)
    List<StockBalance> findLowStock(@Param("orgId") UUID orgId);
}
