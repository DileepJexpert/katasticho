package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.RcpaAudit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RcpaAuditRepository extends JpaRepository<RcpaAudit, UUID> {

    Optional<RcpaAudit> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<RcpaAudit> findByOrgIdAndChemistContactIdAndIsDeletedFalseOrderByAuditDateDesc(
            UUID orgId, UUID chemistContactId);

    List<RcpaAudit> findByOrgIdAndSalespersonIdAndIsDeletedFalseOrderByAuditDateDesc(
            UUID orgId, UUID salespersonId);

    List<RcpaAudit> findByOrgIdAndAuditDateBetweenAndIsDeletedFalse(
            UUID orgId, LocalDate from, LocalDate to);
}
