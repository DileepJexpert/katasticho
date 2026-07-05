package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.PurchaseBill;
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
public interface PurchaseBillRepository extends JpaRepository<PurchaseBill, UUID> {

    Optional<PurchaseBill> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Pessimistic-write variant to serialise concurrent post/pay/void on one bill. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM PurchaseBill b WHERE b.id = :id AND b.orgId = :orgId AND b.isDeleted = false")
    Optional<PurchaseBill> findByIdAndOrgIdForUpdate(@Param("id") UUID id, @Param("orgId") UUID orgId);

    /** All bills of the given vendors — MSME Form 1 walks these (small vendor set). */
    List<PurchaseBill> findByOrgIdAndContactIdInAndIsDeletedFalse(
            UUID orgId, java.util.Collection<UUID> contactIds);

    Page<PurchaseBill> findByOrgIdAndIsDeletedFalseOrderByBillDateDesc(UUID orgId, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndStatusAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, String status, Pageable pageable);

    /** DRAFT bills dated within a period — for the close checklist. */
    long countByOrgIdAndStatusAndIsDeletedFalseAndBillDateBetween(
            UUID orgId, String status, java.time.LocalDate from, java.time.LocalDate to);

    Page<PurchaseBill> findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndBranchIdAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, UUID branchId, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndBillDateBetweenAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, LocalDate from, LocalDate to, Pageable pageable);

    @Query("""
        SELECT b FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.isDeleted = false
          AND (:status IS NULL OR b.status = :status)
          AND (:contactId IS NULL OR b.contactId = :contactId)
          AND (:branchId IS NULL OR b.branchId = :branchId)
          AND (:dateFrom IS NULL OR b.billDate >= :dateFrom)
          AND (:dateTo IS NULL OR b.billDate <= :dateTo)
        ORDER BY b.billDate DESC
    """)
    Page<PurchaseBill> findFiltered(
        @Param("orgId") UUID orgId,
        @Param("status") String status,
        @Param("contactId") UUID contactId,
        @Param("branchId") UUID branchId,
        @Param("dateFrom") LocalDate dateFrom,
        @Param("dateTo") LocalDate dateTo,
        Pageable pageable
    );

    /** Total purchase cost (COGS proxy) for non-cancelled bills in a date range. */
    @Query("""
        SELECT COALESCE(SUM(b.totalAmount), 0) FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.isDeleted = false
          AND b.status <> 'CANCELLED'
          AND b.billDate BETWEEN :from AND :to
    """)
    java.math.BigDecimal sumCogsByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    @Query("""
        SELECT b FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.status IN ('OPEN','PARTIALLY_PAID')
          AND b.dueDate < :asOfDate
          AND b.isDeleted = false
        ORDER BY b.dueDate ASC
    """)
    List<PurchaseBill> findOverdueBills(UUID orgId, LocalDate asOfDate);

    @Query("""
        SELECT b FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.contactId = :contactId
          AND b.status IN ('OPEN','PARTIALLY_PAID','OVERDUE')
          AND b.isDeleted = false
        ORDER BY b.dueDate ASC
    """)
    List<PurchaseBill> findOutstandingByContact(UUID orgId, UUID contactId);

    @Query("""
        SELECT b FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.status IN ('OPEN','PARTIALLY_PAID','OVERDUE')
          AND b.isDeleted = false
        ORDER BY b.dueDate ASC
    """)
    List<PurchaseBill> findOutstandingBills(UUID orgId);

    @Query("""
        SELECT b FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.isDeleted = false
          AND b.status NOT IN ('DRAFT','CANCELLED','VOID')
          AND b.billDate BETWEEN :from AND :to
        ORDER BY b.billDate DESC, b.createdAt DESC
    """)
    List<PurchaseBill> findPostedByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    /** Open bills a debit bank transaction could be paying — bank reconciliation. */
    @Query("""
        SELECT b FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.isDeleted = false
          AND b.status IN ('OPEN','PARTIALLY_PAID','OVERDUE')
          AND b.balanceDue >= :amount
        ORDER BY b.dueDate ASC
    """)
    List<PurchaseBill> findOutstandingBillsForBankMatching(
            UUID orgId, BigDecimal amount, org.springframework.data.domain.Pageable pageable);

    /** Vendor's posted taxable turnover in a range — TDS fiscal-year thresholds. */
    @Query("""
        SELECT COALESCE(SUM(b.subtotal), 0) FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.contactId = :contactId
          AND b.isDeleted = false
          AND b.status NOT IN ('DRAFT','CANCELLED','VOID')
          AND b.billDate BETWEEN :from AND :to
    """)
    BigDecimal sumPostedSubtotalByOrgAndContactAndDateRange(
            UUID orgId, UUID contactId, LocalDate from, LocalDate to);

    @Query("""
        SELECT COALESCE(SUM(b.totalAmount), 0) FROM PurchaseBill b
        WHERE b.orgId = :orgId
          AND b.isDeleted = false
          AND b.status NOT IN ('DRAFT','CANCELLED','VOID')
          AND b.billDate BETWEEN :from AND :to
    """)
    BigDecimal sumPostedTotalByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);
}
