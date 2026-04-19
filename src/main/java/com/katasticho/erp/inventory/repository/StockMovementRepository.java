package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.ReferenceType;
import com.katasticho.erp.inventory.entity.StockMovement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface StockMovementRepository extends JpaRepository<StockMovement, UUID> {

    Page<StockMovement> findByOrgIdAndItemIdOrderByMovementDateDescCreatedAtDesc(
            UUID orgId, UUID itemId, Pageable pageable);

    Page<StockMovement> findByOrgIdAndItemIdAndWarehouseIdOrderByMovementDateDescCreatedAtDesc(
            UUID orgId, UUID itemId, UUID warehouseId, Pageable pageable);

    Page<StockMovement> findByOrgIdOrderByMovementDateDescCreatedAtDesc(UUID orgId, Pageable pageable);

    List<StockMovement> findByReferenceTypeAndReferenceId(ReferenceType referenceType, UUID referenceId);

    /**
     * Canonical on-hand from the ledger. SUM of signed quantities up to and
     * including the given date. Returns 0 if no rows.
     */
    @Query("""
            SELECT COALESCE(SUM(m.quantity), 0)
            FROM StockMovement m
            WHERE m.orgId = :orgId
              AND m.itemId = :itemId
              AND m.warehouseId = :warehouseId
              AND m.movementDate <= :asOfDate
            """)
    BigDecimal computeOnHand(@Param("orgId") UUID orgId,
                             @Param("itemId") UUID itemId,
                             @Param("warehouseId") UUID warehouseId,
                             @Param("asOfDate") LocalDate asOfDate);

    @Query("""
        SELECT m.itemId AS itemId, ABS(SUM(m.quantity)) AS qtySold
        FROM StockMovement m
        WHERE m.orgId = :orgId
          AND m.movementType = 'SALE'
          AND m.movementDate = :date
          AND m.isReversal = false
          AND m.isReversed = false
        GROUP BY m.itemId
        ORDER BY ABS(SUM(m.quantity)) DESC
        LIMIT 5
    """)
    List<TopSellingRow> findTopSellingByDate(@Param("orgId") UUID orgId, @Param("date") LocalDate date);

    interface TopSellingRow {
        UUID getItemId();
        BigDecimal getQtySold();
    }
}
