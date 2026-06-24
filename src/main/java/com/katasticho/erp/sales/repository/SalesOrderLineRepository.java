package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.SalesOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SalesOrderLineRepository extends JpaRepository<SalesOrderLine, UUID> {

    /**
     * Returns backorder lines for a given item, ordered FIFO by order date so
     * the oldest waiting order is fulfilled first when a GRN arrives.
     * JOIN FETCH avoids lazy-loading the parent SO inside the caller.
     */
    @Query("""
        SELECT l FROM SalesOrderLine l
        JOIN FETCH l.salesOrder so
        WHERE l.itemId = :itemId
          AND l.quantityBackordered > 0
          AND so.orgId = :orgId
          AND so.status = 'BACKORDER'
          AND so.isDeleted = false
        ORDER BY so.orderDate ASC, so.createdAt ASC
    """)
    List<SalesOrderLine> findBackorderedLinesForItem(UUID orgId, UUID itemId);

    /**
     * Aggregates total quantityBackordered per item across all BACKORDER SOs for the org.
     * Returns Object[] rows: [itemId (UUID), totalBackordered (BigDecimal)]
     */
    @Query("""
        SELECT l.itemId, SUM(l.quantityBackordered)
        FROM SalesOrderLine l
        JOIN l.salesOrder so
        WHERE so.orgId = :orgId
          AND so.status = 'BACKORDER'
          AND so.isDeleted = false
          AND l.itemId IS NOT NULL
          AND l.quantityBackordered > 0
        GROUP BY l.itemId
    """)
    List<Object[]> findAllBackorderedItems(@Param("orgId") UUID orgId);

    /**
     * SO lines for a given item that still have un-shipped commitment
     * ({@code quantityShipped < quantity}) on an open
     * (CONFIRMED / BACKORDER / PARTIALLY_SHIPPED) SO. Powers the ATP
     * commitment calculation — caller filters the SO header status set in
     * Java to keep the JPQL parameter list short.
     */
    @Query("""
        SELECT l FROM SalesOrderLine l
        JOIN FETCH l.salesOrder so
        WHERE l.itemId = :itemId
          AND so.orgId = :orgId
          AND so.isDeleted = false
          AND so.status IN ('CONFIRMED', 'BACKORDER', 'PARTIALLY_SHIPPED')
          AND l.quantityShipped < l.quantity
    """)
    List<SalesOrderLine> findOpenCommitmentLinesForItem(
            @Param("orgId") UUID orgId, @Param("itemId") UUID itemId);
}
