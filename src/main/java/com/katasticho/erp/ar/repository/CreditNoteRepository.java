package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.CreditNote;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CreditNoteRepository extends JpaRepository<CreditNote, UUID> {

    Optional<CreditNote> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Pessimistic-write variant used by the issue path to serialise double-submits. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM CreditNote c WHERE c.id = :id AND c.orgId = :orgId AND c.isDeleted = false")
    Optional<CreditNote> findLockedByIdAndOrgIdAndIsDeletedFalse(@Param("id") UUID id, @Param("orgId") UUID orgId);

    Page<CreditNote> findByOrgIdAndIsDeletedFalseOrderByCreditNoteDateDesc(UUID orgId, Pageable pageable);

    List<CreditNote> findByOrgIdAndIsDeletedFalseAndCreditNoteDateBetweenAndStatusNot(
            UUID orgId, LocalDate from, LocalDate to, String excludeStatus);
}
