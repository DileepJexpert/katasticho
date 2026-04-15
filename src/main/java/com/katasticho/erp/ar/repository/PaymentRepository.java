package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.Payment;
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
public interface PaymentRepository extends JpaRepository<Payment, UUID> {

    Optional<Payment> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Payment> findByOrgIdAndIsDeletedFalseOrderByPaymentDateDesc(UUID orgId, Pageable pageable);

    List<Payment> findByInvoiceIdAndIsDeletedFalse(UUID invoiceId);

    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.invoiceId = :invoiceId AND p.isDeleted = false")
    BigDecimal sumPaymentsByInvoice(UUID invoiceId);

    // ─── Dashboard aggregation queries ───────────────────────────────────

    /** Total cash collected (all payment methods) for an org in a date range. */
    @Query("""
        SELECT COALESCE(SUM(p.amount), 0) FROM Payment p
        WHERE p.orgId = :orgId
          AND p.isDeleted = false
          AND p.paymentDate BETWEEN :from AND :to
    """)
    BigDecimal sumCollectedByOrgAndDateRange(UUID orgId, LocalDate from, LocalDate to);

    /** Total cash collected for an org/branch in a date range. */
    @Query("""
        SELECT COALESCE(SUM(p.amount), 0) FROM Payment p
        WHERE p.orgId = :orgId
          AND p.branchId = :branchId
          AND p.isDeleted = false
          AND p.paymentDate BETWEEN :from AND :to
    """)
    BigDecimal sumCollectedByOrgBranchAndDateRange(UUID orgId, UUID branchId, LocalDate from, LocalDate to);
}
