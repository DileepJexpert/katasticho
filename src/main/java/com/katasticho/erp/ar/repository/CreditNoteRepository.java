package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.CreditNote;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CreditNoteRepository extends JpaRepository<CreditNote, UUID> {

    Optional<CreditNote> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Page<CreditNote> findByOrgIdAndIsDeletedFalseOrderByCreditNoteDateDesc(UUID orgId, Pageable pageable);
}
