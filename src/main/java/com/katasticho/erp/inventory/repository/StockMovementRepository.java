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
     * All incoming (positive, non-reversal) movements for the org, newest
     * first per item — feeds the stock-ageing report's FIFO allocation
     * (what's left on hand is assumed to be the most recent receipts).
     */
    @Query("""
        SELECT m FROM StockMovement m
        WHERE m.orgId = :orgId
          AND m.quantity > 0
          AND m.reversal = false
          AND m.reversed = false
        ORDER BY m.itemId, m.movementDate DESC, m.createdAt DESC
    """)
    List<StockMovement> findIncomingByOrgNewestFirst(@Param("orgId") UUID orgId);

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
          AND m.reversal = false
          AND m.reversed = false
        GROUP BY m.itemId
        ORDER BY ABS(SUM(m.quantity)) DESC
        LIMIT 5
    """)
    List<TopSellingRow> findTopSellingByDate(@Param("orgId") UUID orgId, @Param("date") LocalDate date);

    interface TopSellingRow {
        UUID getItemId();
        BigDecimal getQtySold();
    }

    @Query("""
        SELECT COALESCE(SUM(ABS(m.totalCost)), 0)
        FROM StockMovement m
        WHERE m.orgId = :orgId
          AND m.movementType = 'SALE'
          AND m.movementDate BETWEEN :from AND :to
          AND m.reversal = false
          AND m.reversed = false
    """)
    BigDecimal sumSalesCostByOrgAndDateRange(@Param("orgId") UUID orgId,
                                             @Param("from") LocalDate from,
                                             @Param("to") LocalDate to);

    List<StockMovement> findByOrgIdAndMovementDateBetweenOrderByMovementDateDescCreatedAtDesc(
            UUID orgId, LocalDate from, LocalDate to);

    /**
     * Actual recorded cost of the SALE movements attributable to the given
     * references (e.g. an invoice's delivery challans). Under FIFO each such
     * movement's total_cost is the true cost-of-goods for the units it
     * dispatched, so summing them gives FIFO COGS for the invoice. Returns 0
     * when there are no matching movements.
     */
    @Query("""
        SELECT COALESCE(SUM(ABS(m.totalCost)), 0)
        FROM StockMovement m
        WHERE m.orgId = :orgId
          AND m.referenceType = :refType
          AND m.referenceId IN :refIds
          AND m.movementType = 'SALE'
          AND m.reversal = false
          AND m.reversed = false
    """)
    BigDecimal sumSaleCostByReferences(@Param("orgId") UUID orgId,
                                       @Param("refType") ReferenceType refType,
                                       @Param("refIds") List<UUID> refIds);
}
