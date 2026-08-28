package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.StoreMerchandisingAudit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StoreMerchandisingAuditRepository extends JpaRepository<StoreMerchandisingAudit, UUID> {

    List<StoreMerchandisingAudit> findByOrgIdAndFieldVisitIdAndIsDeletedFalseOrderByAuditedAtDesc(UUID orgId, UUID fieldVisitId);

    List<StoreMerchandisingAudit> findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderByAuditedAtDesc(UUID orgId, UUID routeExecutionId);

    List<StoreMerchandisingAudit> findByOrgIdAndContactIdAndIsDeletedFalseOrderByAuditedAtDesc(UUID orgId, UUID contactId);

    List<StoreMerchandisingAudit> findByOrgIdAndAuditedAtBetweenAndIsDeletedFalseOrderByAuditedAtDesc(UUID orgId, Instant from, Instant to);

    Optional<StoreMerchandisingAudit> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    long countByOrgIdAndFieldVisitIdAndIsDeletedFalse(UUID orgId, UUID fieldVisitId);
}
