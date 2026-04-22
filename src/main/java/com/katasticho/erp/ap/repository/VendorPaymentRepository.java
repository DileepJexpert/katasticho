package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.VendorPayment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface VendorPaymentRepository extends JpaRepository<VendorPayment, UUID> {

    Optional<VendorPayment> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<VendorPayment> findByOrgIdAndIsDeletedFalseOrderByPaymentDateDesc(UUID orgId, Pageable pageable);

    Page<VendorPayment> findByOrgIdAndContactIdAndIsDeletedFalseOrderByPaymentDateDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    Page<VendorPayment> findByOrgIdAndPaymentDateBetweenAndIsDeletedFalseOrderByPaymentDateDesc(
            UUID orgId, LocalDate from, LocalDate to, Pageable pageable);

    Page<VendorPayment> findByOrgIdAndPaymentModeAndIsDeletedFalseOrderByPaymentDateDesc(
            UUID orgId, String paymentMode, Pageable pageable);

    List<VendorPayment> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId);

    @Query("""
        SELECT p FROM VendorPayment p
        WHERE p.orgId = :orgId
          AND p.isDeleted = false
          AND (:contactId IS NULL OR p.contactId = :contactId)
          AND (:dateFrom IS NULL OR p.paymentDate >= :dateFrom)
          AND (:dateTo IS NULL OR p.paymentDate <= :dateTo)
        ORDER BY p.paymentDate DESC
    """)
    Page<VendorPayment> findFiltered(
        @Param("orgId") UUID orgId,
        @Param("contactId") UUID contactId,
        @Param("dateFrom") LocalDate dateFrom,
        @Param("dateTo") LocalDate dateTo,
        Pageable pageable
    );

    @Query("""
        SELECT DISTINCT p FROM VendorPayment p
        JOIN p.allocations a
        WHERE p.orgId = :orgId
          AND a.purchaseBillId = :billId
          AND p.isDeleted = false
        ORDER BY p.paymentDate DESC
    """)
    List<VendorPayment> findByOrgIdAndBillId(@Param("orgId") UUID orgId, @Param("billId") UUID billId);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.orgId = :orgId AND p.paymentDate = :date AND p.isDeleted = false")
    java.math.BigDecimal sumAmountByOrgAndDate(UUID orgId, LocalDate date);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM VendorPayment p WHERE p.orgId = :orgId AND p.isDeleted = false AND p.paymentDate BETWEEN :from AND :to")
    java.math.BigDecimal sumAmountByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);
}
