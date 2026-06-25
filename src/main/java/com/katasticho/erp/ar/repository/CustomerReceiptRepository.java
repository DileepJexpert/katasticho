package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.CustomerReceipt;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerReceiptRepository extends JpaRepository<CustomerReceipt, UUID> {

    Optional<CustomerReceipt> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<CustomerReceipt> findByOrgIdAndIsDeletedFalseOrderByReceiptDateDesc(UUID orgId, Pageable pageable);

    Page<CustomerReceipt> findByOrgIdAndContactIdAndIsDeletedFalseOrderByReceiptDateDesc(
            UUID orgId, UUID contactId, Pageable pageable);

    /** Receipts that touched a given invoice (for the invoice detail screen). */
    @Query("""
        SELECT DISTINCT r FROM CustomerReceipt r
        JOIN r.allocations a
        WHERE r.orgId = :orgId
          AND a.invoiceId = :invoiceId
          AND r.isDeleted = false
        ORDER BY r.receiptDate DESC
    """)
    List<CustomerReceipt> findByOrgIdAndInvoiceId(@Param("orgId") UUID orgId, @Param("invoiceId") UUID invoiceId);

    /**
     * Total unallocated advance a customer is currently sitting on (sum of the
     * advance leg across all their non-voided receipts). With no "apply
     * advance" draw-down yet, this is the gross advance collected.
     */
    @Query("""
        SELECT COALESCE(SUM(r.advanceAmount), 0) FROM CustomerReceipt r
        WHERE r.orgId = :orgId
          AND r.contactId = :contactId
          AND r.isDeleted = false
    """)
    BigDecimal sumAdvanceByContact(@Param("orgId") UUID orgId, @Param("contactId") UUID contactId);
}
