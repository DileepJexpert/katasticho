package com.katasticho.erp.recurring.repository;

import com.katasticho.erp.recurring.entity.RecurringInvoice;
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
public interface RecurringInvoiceRepository extends JpaRepository<RecurringInvoice, UUID> {

    Optional<RecurringInvoice> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<RecurringInvoice> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, Pageable pageable);

    Page<RecurringInvoice> findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String status, Pageable pageable);

    /**
     * Scheduler entry point — every ACTIVE template whose
     * next_invoice_date is today or earlier, across ALL orgs. The
     * caller is responsible for walking results and setting the
     * per-row tenant context before generating.
     */
    @Query("""
        SELECT r FROM RecurringInvoice r
        WHERE r.isDeleted = false
          AND r.status = 'ACTIVE'
          AND r.nextInvoiceDate <= :today
        ORDER BY r.nextInvoiceDate ASC
    """)
    List<RecurringInvoice> findDueTemplates(LocalDate today);
}
