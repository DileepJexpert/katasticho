package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.StockReceiptLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Read-side helper for the P2P loop. The receivedQuantity field on
 * {@link com.katasticho.erp.procurement.entity.PurchaseOrderLine} is now
 * authoritative (incremented on GRN receive / decremented on GRN cancel),
 * but we also keep these aggregate queries to compute remaining-to-receive
 * defensively from the GRN history itself — both for {@code createGrnFromPo}
 * (so it works even before any receive() has updated receivedQuantity) and
 * for the 3-way match service (which reads "what was actually received").
 */
@Repository
public interface StockReceiptLineRepository extends JpaRepository<StockReceiptLine, UUID> {

    /** All GRN lines (across receipts) pointing at this PO line. */
    List<StockReceiptLine> findByPurchaseOrderLineId(UUID purchaseOrderLineId);

    /**
     * Sum of received qty across all non-cancelled GRN lines for a given PO line.
     * RECEIVED + DRAFT are both counted (planner has earmarked the qty); only
     * CANCELLED receipts are excluded.
     */
    @Query("SELECT COALESCE(SUM(l.quantity), 0) FROM StockReceiptLine l " +
           "JOIN l.receipt r " +
           "WHERE l.purchaseOrderLineId = :poLineId " +
           "AND r.isDeleted = false " +
           "AND r.status <> 'CANCELLED'")
    BigDecimal sumQuantityForPurchaseOrderLine(@Param("poLineId") UUID poLineId);

    /**
     * Sum of received qty for RECEIVED-status GRN lines only. Used by 3-way match
     * — only stock that's actually on the books should count against billed qty.
     */
    @Query("SELECT COALESCE(SUM(l.quantity), 0) FROM StockReceiptLine l " +
           "JOIN l.receipt r " +
           "WHERE l.purchaseOrderLineId = :poLineId " +
           "AND r.isDeleted = false " +
           "AND r.status = 'RECEIVED'")
    BigDecimal sumReceivedQuantityForPurchaseOrderLine(@Param("poLineId") UUID poLineId);
}
