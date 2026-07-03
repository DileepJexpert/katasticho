package com.katasticho.erp.dunning.repository;

import com.katasticho.erp.dunning.entity.DunningLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface DunningLogRepository extends JpaRepository<DunningLog, UUID> {

    /** Idempotency guard: has this level already been SENT for this invoice? */
    boolean existsByOrgIdAndInvoiceIdAndDunningLevelIdAndOutcomeAndIsDeletedFalse(
            UUID orgId, UUID invoiceId, UUID dunningLevelId, String outcome);

    Page<DunningLog> findByOrgIdAndIsDeletedFalseOrderBySentAtDesc(UUID orgId, Pageable pageable);

    List<DunningLog> findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderBySentAtDesc(UUID orgId, UUID invoiceId);
}
