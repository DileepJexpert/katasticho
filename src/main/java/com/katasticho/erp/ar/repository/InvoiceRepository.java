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

    Page<Invoice> findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(UUID orgId, UUID contactId, Pageable pageable);

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
}
