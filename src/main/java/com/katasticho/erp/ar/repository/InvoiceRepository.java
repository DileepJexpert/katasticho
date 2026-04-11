package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.Invoice;
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
public interface InvoiceRepository extends JpaRepository<Invoice, UUID> {

    Optional<Invoice> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<Invoice> findByOrgIdAndIsDeletedFalseOrderByInvoiceDateDesc(UUID orgId, Pageable pageable);

    Page<Invoice> findByOrgIdAndCustomerIdAndIsDeletedFalseOrderByInvoiceDateDesc(UUID orgId, UUID customerId, Pageable pageable);

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
          AND i.customerId = :customerId
          AND i.status IN ('SENT','PARTIALLY_PAID','OVERDUE')
          AND i.isDeleted = false
        ORDER BY i.dueDate ASC
    """)
    List<Invoice> findOutstandingByCustomer(UUID orgId, UUID customerId);
}
