package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.CostLot;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CostLotRepository extends JpaRepository<CostLot, UUID> {

    /**
     * Active lots for an item×warehouse in FIFO order (oldest first).
     * Row-locked so two concurrent issues serialize their draw-downs instead
     * of both consuming the same lot units.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT l FROM CostLot l
            WHERE l.orgId = :orgId
              AND l.itemId = :itemId
              AND l.warehouseId = :warehouseId
              AND l.active = true
              AND l.remainingQty > 0
            ORDER BY l.receivedDate ASC, l.createdAt ASC
    """)
    List<CostLot> findOpenLots(@Param("orgId") UUID orgId,
                               @Param("itemId") UUID itemId,
                               @Param("warehouseId") UUID warehouseId);

    /** Every active lot with stock left — for the org-wide valuation report. */
    @Query("""
            SELECT l FROM CostLot l
            WHERE l.orgId = :orgId
              AND l.active = true
              AND l.remainingQty > 0
            ORDER BY l.itemId, l.warehouseId, l.receivedDate ASC, l.createdAt ASC
    """)
    List<CostLot> findAllOpenLots(@Param("orgId") UUID orgId);

    boolean existsByOrgIdAndItemIdAndWarehouseId(UUID orgId, UUID itemId, UUID warehouseId);

    Optional<CostLot> findBySourceMovementId(UUID sourceMovementId);
}
