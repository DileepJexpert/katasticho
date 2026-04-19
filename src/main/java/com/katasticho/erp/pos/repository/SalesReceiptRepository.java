package com.katasticho.erp.pos.repository;

import com.katasticho.erp.pos.entity.SalesReceipt;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SalesReceiptRepository extends JpaRepository<SalesReceipt, UUID> {

    Optional<SalesReceipt> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    @Query("""
        SELECT r FROM SalesReceipt r
        WHERE r.orgId = :orgId
          AND r.isDeleted = false
          AND (:branchId IS NULL OR r.branchId = :branchId)
          AND (:dateFrom IS NULL OR r.receiptDate >= :dateFrom)
          AND (:dateTo IS NULL OR r.receiptDate <= :dateTo)
          AND (:paymentMode IS NULL OR CAST(r.paymentMode AS string) = :paymentMode)
        ORDER BY r.createdAt DESC
    """)
    Page<SalesReceipt> findFiltered(UUID orgId, UUID branchId,
                                     LocalDate dateFrom, LocalDate dateTo,
                                     String paymentMode, Pageable pageable);

    @Query("SELECT COALESCE(SUM(r.total), 0) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate = :date AND r.isDeleted = false")
    BigDecimal sumTotalByOrgAndDate(UUID orgId, LocalDate date);

    @Query("SELECT COUNT(r) FROM SalesReceipt r WHERE r.orgId = :orgId AND r.receiptDate = :date AND r.isDeleted = false")
    long countByOrgAndDate(UUID orgId, LocalDate date);
}
