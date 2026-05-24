package com.katasticho.erp.pharma.repository;

import com.katasticho.erp.pharma.entity.PrescriptionRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PrescriptionRecordRepository extends JpaRepository<PrescriptionRecord, UUID> {

    Page<PrescriptionRecord> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    List<PrescriptionRecord> findByOrgIdAndContactIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, UUID contactId);

    Optional<PrescriptionRecord> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<PrescriptionRecord> findByReceiptIdAndOrgIdAndIsDeletedFalse(UUID receiptId, UUID orgId);
}
