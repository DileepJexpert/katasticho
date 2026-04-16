package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.PurchaseBill;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PurchaseBillRepository extends JpaRepository<PurchaseBill, UUID> {

    Optional<PurchaseBill> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<PurchaseBill> findByOrgIdAndIsDeletedFalseOrderByBillDateDesc(UUID orgId, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndStatusAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, String status, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndBranchIdAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, UUID branchId, Pageable pageable);

    Page<PurchaseBill> findByOrgIdAndBillDateBetweenAndIsDeletedFalseOrderByBillDateDesc(
            UUID orgId, LocalDate from, LocalDate to, Pageable pageable);

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
}
