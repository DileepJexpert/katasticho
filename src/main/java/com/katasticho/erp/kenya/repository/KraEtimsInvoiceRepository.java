package com.katasticho.erp.kenya.repository;

import com.katasticho.erp.kenya.entity.KraEtimsInvoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface KraEtimsInvoiceRepository extends JpaRepository<KraEtimsInvoice, UUID> {
    List<KraEtimsInvoice> findByOrgIdAndIsDeletedFalseOrderBySubmittedAtDesc(UUID orgId);
    Optional<KraEtimsInvoice> findByOrgIdAndInvoiceIdAndIsDeletedFalse(UUID orgId, UUID invoiceId);
    Optional<KraEtimsInvoice> findByOrgIdAndIdAndIsDeletedFalse(UUID orgId, UUID id);
}