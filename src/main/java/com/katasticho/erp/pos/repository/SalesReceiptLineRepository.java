package com.katasticho.erp.pos.repository;

import com.katasticho.erp.pos.entity.SalesReceiptLine;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface SalesReceiptLineRepository extends JpaRepository<SalesReceiptLine, UUID> {

    List<SalesReceiptLine> findByReceiptIdOrderByLineNumber(UUID receiptId);

    @Query("""
        SELECT l.itemId               AS itemId,
               MAX(l.description)     AS description,
               SUM(l.quantity)        AS totalQty,
               SUM(l.amount)         AS totalRevenue
        FROM SalesReceiptLine l
        WHERE l.receipt.orgId = :orgId
          AND l.receipt.isDeleted = false
          AND l.receipt.receiptDate BETWEEN :from AND :to
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
