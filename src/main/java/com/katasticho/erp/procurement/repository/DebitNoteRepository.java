package com.katasticho.erp.procurement.repository;

import com.katasticho.erp.procurement.entity.DebitNote;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface DebitNoteRepository extends JpaRepository<DebitNote, UUID> {

    Page<DebitNote> findByOrgIdAndIsDeletedFalseOrderByNoteDateDesc(UUID orgId, Pageable pageable);

    Page<DebitNote> findByOrgIdAndStatusAndIsDeletedFalse(UUID orgId, String status, Pageable pageable);

    Page<DebitNote> findByOrgIdAndSupplierIdAndIsDeletedFalse(UUID orgId, UUID supplierId, Pageable pageable);

    Optional<DebitNote> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
