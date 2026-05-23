package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.SalesOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
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
}
