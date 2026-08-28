package com.katasticho.erp.inventory.subcontracting.repository;

import com.katasticho.erp.inventory.subcontracting.entity.JobWorkReceiptLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface JobWorkReceiptLineRepository extends JpaRepository<JobWorkReceiptLine, UUID> {

    List<JobWorkReceiptLine> findByOrgIdAndJobWorkOrderIdAndIsDeletedFalse(UUID orgId, UUID jobWorkOrderId);

    Optional<JobWorkReceiptLine> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<JobWorkReceiptLine> findByOrgIdAndReceiptDateBetweenAndIsDeletedFalse(
            UUID orgId, LocalDate startDate, LocalDate endDate);
}
