package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.InvoiceLine;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface InvoiceLineRepository extends JpaRepository<InvoiceLine, UUID> {

    List<InvoiceLine> findByInvoiceIdOrderByLineNumber(UUID invoiceId);

    /**
     * Top-selling items by total quantity invoiced in a date range.
     * Returns (itemId, description, totalQty, totalRevenue) tuples.
     * Free-text lines (itemId IS NULL) are excluded so the rollup is
     * meaningful for the dashboard.
     */
    @Query("""
        SELECT l.itemId               AS itemId,
               MAX(l.description)     AS description,
               SUM(l.quantity)        AS totalQty,
               SUM(l.lineTotal)       AS totalRevenue
        FROM InvoiceLine l
        WHERE l.invoice.orgId = :orgId
          AND l.invoice.isDeleted = false
          AND l.invoice.status <> 'CANCELLED'
          AND l.invoice.invoiceDate BETWEEN :from AND :to
          AND l.itemId IS NOT NULL
        GROUP BY l.itemId
        ORDER BY SUM(l.quantity) DESC
    """)
    List<TopSellingRow> findTopSelling(UUID orgId, LocalDate from, LocalDate to, Pageable pageable);

    interface TopSellingRow {
        UUID getItemId();
        String getDescription();
        BigDecimal getTotalQty();
        BigDecimal getTotalRevenue();
    }
}
