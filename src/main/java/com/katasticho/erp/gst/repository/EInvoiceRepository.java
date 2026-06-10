package com.katasticho.erp.gst.repository;

import com.katasticho.erp.gst.entity.EInvoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EInvoiceRepository extends JpaRepository<EInvoice, UUID> {

    Optional<EInvoice> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    boolean existsByOrgIdAndInvoiceIdAndIsDeletedFalse(UUID orgId, UUID invoiceId);

    List<EInvoice> findByOrgIdAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(UUID orgId);

    List<EInvoice> findByOrgIdAndStatusAndIsDeletedFalseOrderByDocumentDateDescCreatedAtDesc(
            UUID orgId, String status);

    long countByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status);
}
