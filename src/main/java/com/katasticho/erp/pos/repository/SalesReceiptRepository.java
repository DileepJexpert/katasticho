package com.katasticho.erp.pos.repository;

import com.katasticho.erp.pos.entity.SalesReceipt;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SalesReceiptRepository extends JpaRepository<SalesReceipt, UUID> {

    Optional<SalesReceipt> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /**
     * Filtered receipt list. Uses a native query so PostgreSQL can infer the
     * type of nullable parameters via explicit CAST — JPQL's
     * <code>(:param IS NULL OR ...)</code> pattern fails on PostgreSQL with
     * "could not determine data type of parameter".
     */
    @Query(value = """
        SELECT * FROM sales_receipt r
        WHERE r.org_id = CAST(:orgId AS uuid)
          AND r.is_deleted = false
          AND (CAST(:branchId AS text) IS NULL OR r.branch_id = CAST(:branchId AS uuid))
          AND (CAST(:dateFrom AS text) IS NULL OR r.receipt_date >= CAST(:dateFrom AS date))
          AND (CAST(:dateTo AS text) IS NULL OR r.receipt_date <= CAST(:dateTo AS date))
          AND (CAST(:paymentMode AS text) IS NULL OR r.payment_mode = :paymentMode)
        ORDER BY r.created_at DESC
        """,
        countQuery = """
        SELECT COUNT(*) FROM sales_receipt r
        WHERE r.org_id = CAST(:orgId AS uuid)
          AND r.is_deleted = false
          AND (CAST(:branchId AS text) IS NULL OR r.branch_id = CAST(:branchId AS uuid))
          AND (CAST(:dateFrom AS text) IS NULL OR r.receipt_date >= CAST(:dateFrom AS date))
          AND (CAST(:dateTo AS text) IS NULL OR r.receipt_date <= CAST(:dateTo AS date))
          AND (CAST(:paymentMode AS text) IS NULL OR r.payment_mode = :paymentMode)
        """,
        nativeQuery = true)
    Page<SalesReceipt> findFiltered(@Param("orgId") String orgId,
                                     @Param("branchId") String branchId,
                                     @Param("dateFrom") String dateFrom,
                                     @Param("dateTo") String dateTo,
                                     @Param("paymentMode") String paymentMode,
                                     Pageable pageable);

    @Query("SELECT COALESCE(SUM(r.total), 0) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate = :date AND r.isDeleted = false")
    BigDecimal sumTotalByOrgAndDate(UUID orgId, LocalDate date);

    @Query("SELECT COUNT(r) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate = :date AND r.isDeleted = false")
    long countByOrgAndDate(UUID orgId, LocalDate date);

    @Query("SELECT COALESCE(SUM(r.total), 0) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate BETWEEN :from AND :to AND r.isDeleted = false")
    BigDecimal sumTotalByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    @Query("SELECT COALESCE(SUM(r.total), 0) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.branchId = :branchId AND r.receiptDate BETWEEN :from AND :to AND r.isDeleted = false")
    BigDecimal sumTotalByOrgBranchAndDateRange(UUID orgId, UUID branchId, LocalDate from, LocalDate to);

    @Query("""
        SELECT r.branchId AS branchId, COALESCE(SUM(r.total), 0) AS total
        FROM SalesReceipt r
        WHERE r.orgId = :orgId AND r.isDeleted = false
          AND r.receiptDate BETWEEN :from AND :to
          AND r.branchId IS NOT NULL
        GROUP BY r.branchId
    """)
    List<RevenueByBranchRow> sumTotalByBranch(UUID orgId, LocalDate from, LocalDate to);

    interface RevenueByBranchRow {
        UUID getBranchId();
        BigDecimal getTotal();
    }

    @Query("""
        SELECT r.receiptDate AS date, COALESCE(SUM(r.total), 0) AS total
        FROM SalesReceipt r
        WHERE r.orgId = :orgId AND r.isDeleted = false
          AND r.receiptDate BETWEEN :from AND :to
        GROUP BY r.receiptDate
        ORDER BY r.receiptDate
    """)
    List<DailyRevenueRow> sumTotalDailyByOrg(UUID orgId, LocalDate from, LocalDate to);

    interface DailyRevenueRow {
        LocalDate getDate();
        BigDecimal getTotal();
    }

    @Query("SELECT COUNT(r) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate BETWEEN :from AND :to AND r.isDeleted = false")
    long countByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    @Query("""
        SELECT r FROM SalesReceipt r
        WHERE r.orgId = :orgId AND r.isDeleted = false
          AND r.receiptDate BETWEEN :from AND :to
        ORDER BY r.createdAt DESC
    """)
    List<SalesReceipt> findRecentByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to, Pageable pageable);
}
