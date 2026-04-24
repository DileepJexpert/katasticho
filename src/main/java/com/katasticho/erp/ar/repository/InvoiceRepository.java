package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.Invoice;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface InvoiceRepository extends JpaRepository<Invoice, UUID> {

    Optional<Invoice> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Invoice> findByOrgIdAndIsDeletedFalseOrderByInvoiceDateDesc(UUID orgId, Pageable pageable);

    Page<Invoice> findByOrgIdAndStatusAndIsDeletedFalseOrderByInvoiceDateDesc(UUID orgId, String status, Pageable pageable);

    Page<Invoice> findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(UUID orgId, UUID contactId, Pageable pageable);

    @Query("""
        SELECT i FROM Invoice i LEFT JOIN Contact c ON c.id = i.contactId
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND (LOWER(i.invoiceNumber) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(c.displayName) LIKE LOWER(CONCAT('%', :search, '%')))
        ORDER BY i.invoiceDate DESC
    """)
    Page<Invoice> searchByOrgId(UUID orgId, String search, Pageable pageable);

    @Query("""
        SELECT i FROM Invoice i LEFT JOIN Contact c ON c.id = i.contactId
        WHERE i.orgId = :orgId
          AND i.status = :status
          AND i.isDeleted = false
          AND (LOWER(i.invoiceNumber) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(c.displayName) LIKE LOWER(CONCAT('%', :search, '%')))
        ORDER BY i.invoiceDate DESC
    """)
    Page<Invoice> searchByOrgIdAndStatus(UUID orgId, String status, String search, Pageable pageable);

    @Query("""
        SELECT i FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.status IN ('SENT','PARTIALLY_PAID','OVERDUE')
          AND i.isDeleted = false
        ORDER BY i.dueDate ASC
    """)
    List<Invoice> findOutstandingInvoices(UUID orgId);

    @Query("""
        SELECT i FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.status IN ('SENT','PARTIALLY_PAID','OVERDUE')
          AND i.isDeleted = false
          AND i.dueDate < :asOfDate
        ORDER BY i.dueDate ASC
    """)
    List<Invoice> findOverdueInvoices(UUID orgId, LocalDate asOfDate);

    @Query("""
        SELECT i FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.contactId = :contactId
          AND i.status IN ('SENT','PARTIALLY_PAID','OVERDUE')
          AND i.isDeleted = false
        ORDER BY i.dueDate ASC
    """)
    List<Invoice> findOutstandingByContact(UUID orgId, UUID contactId);

    // ─── Dashboard aggregation queries ───────────────────────────────────

    /** Total outstanding AR (sum of balanceDue) for all open invoices. */
    @Query("""
        SELECT COALESCE(SUM(i.balanceDue), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status IN ('SENT','PARTIALLY_PAID','OVERDUE')
    """)
    java.math.BigDecimal sumOutstandingAr(UUID orgId);

    /** Total invoiced revenue for an org within a date range (inclusive). */
    @Query("""
        SELECT COALESCE(SUM(i.totalAmount), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status <> 'CANCELLED'
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    BigDecimal sumRevenueByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    /** Total invoiced revenue for an org/branch within a date range. */
    @Query("""
        SELECT COALESCE(SUM(i.totalAmount), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.branchId = :branchId
          AND i.isDeleted = false
          AND i.status <> 'CANCELLED'
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    BigDecimal sumRevenueByOrgBranchAndDateRange(UUID orgId, UUID branchId, LocalDate from, LocalDate to);

    /** Per-branch revenue rollup for a date range. Returns (branchId, total). */
    @Query("""
        SELECT i.branchId AS branchId, COALESCE(SUM(i.totalAmount), 0) AS total
        FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status <> 'CANCELLED'
          AND i.invoiceDate BETWEEN :from AND :to
          AND i.branchId IS NOT NULL
        GROUP BY i.branchId
    """)
    List<RevenueByBranchRow> sumRevenueByBranch(UUID orgId, LocalDate from, LocalDate to);

    interface RevenueByBranchRow {
        UUID getBranchId();
        BigDecimal getTotal();
    }

    /** Daily revenue totals for trend chart (one row per day that had invoices). */
    @Query("""
        SELECT i.invoiceDate AS date, COALESCE(SUM(i.totalAmount), 0) AS total
        FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status <> 'CANCELLED'
          AND i.invoiceDate >= :from
          AND i.invoiceDate <= :to
        GROUP BY i.invoiceDate
        ORDER BY i.invoiceDate
    """)
    List<DailyRevenueRow> sumRevenueDailyByOrg(UUID orgId, LocalDate from, LocalDate to);

    interface DailyRevenueRow {
        LocalDate getDate();
        BigDecimal getTotal();
    }

    List<Invoice> findBySalesOrderIdAndOrgId(UUID salesOrderId, UUID orgId);

    int countBySalesOrderId(UUID salesOrderId);

    @Query("""
        SELECT i FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.status IN ('SENT','PARTIALLY_PAID','OVERDUE')
          AND i.isDeleted = false
          AND i.dueDate IN :dates
    """)
    List<Invoice> findDueOnDates(UUID orgId, List<LocalDate> dates);

    @Query("""
        SELECT COUNT(i) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status <> 'CANCELLED'
          AND i.invoiceDate = :date
    """)
    long countByOrgAndDate(UUID orgId, LocalDate date);

    @Query("""
        SELECT COUNT(i) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status NOT IN ('DRAFT','CANCELLED')
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    long countByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    @Query("""
        SELECT COALESCE(SUM(i.totalAmount), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status NOT IN ('DRAFT','PAID','CANCELLED')
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    BigDecimal sumCreditSalesByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    @Query("""
        SELECT COALESCE(SUM(i.totalAmount), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.branchId = :branchId
          AND i.isDeleted = false
          AND i.status NOT IN ('DRAFT','PAID','CANCELLED')
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    BigDecimal sumCreditSalesByOrgBranchAndDateRange(UUID orgId, UUID branchId, LocalDate from, LocalDate to);

    @Query("""
        SELECT COALESCE(SUM(i.totalAmount), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status = 'PAID'
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    BigDecimal sumPaidInvoicesByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    @Query("""
        SELECT COALESCE(SUM(i.totalAmount), 0) FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.branchId = :branchId
          AND i.isDeleted = false
          AND i.status = 'PAID'
          AND i.invoiceDate BETWEEN :from AND :to
    """)
    BigDecimal sumPaidInvoicesByOrgBranchAndDateRange(UUID orgId, UUID branchId, LocalDate from, LocalDate to);

    @Query("""
        SELECT i FROM Invoice i
        WHERE i.orgId = :orgId
          AND i.isDeleted = false
          AND i.status NOT IN ('DRAFT','CANCELLED')
          AND i.invoiceDate BETWEEN :from AND :to
        ORDER BY i.createdAt DESC
    """)
    List<Invoice> findRecentByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to, Pageable pageable);
}
