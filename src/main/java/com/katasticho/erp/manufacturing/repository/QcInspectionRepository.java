package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.QcInspection;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface QcInspectionRepository extends JpaRepository<QcInspection, UUID> {

    Page<QcInspection> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId, Pageable pageable);

    Optional<QcInspection> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<QcInspection> findByReferenceTypeAndReferenceIdAndIsDeletedFalse(
            String referenceType, UUID referenceId);
}
