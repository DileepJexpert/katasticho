package com.katasticho.erp.paymentterm.repository;

import com.katasticho.erp.paymentterm.entity.InvoiceInstalment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface InvoiceInstalmentRepository extends JpaRepository<InvoiceInstalment, UUID> {

    List<InvoiceInstalment> findByInvoiceIdAndIsDeletedFalseOrderBySeqAsc(UUID invoiceId);

    boolean existsByInvoiceIdAndIsDeletedFalse(UUID invoiceId);

    /** Replace-style: re-applying a term hard-deletes the prior schedule. */
    @Transactional
    void deleteByInvoiceId(UUID invoiceId);

    /** Distinct invoice ids in the org that carry an instalment due before the cut-off. */
    @Query("SELECT DISTINCT i.invoiceId FROM InvoiceInstalment i " +
            "WHERE i.orgId = :orgId AND i.isDeleted = false AND i.dueDate < :cutoff")
    List<UUID> findInvoiceIdsWithInstalmentDueBefore(UUID orgId, LocalDate cutoff);
}
