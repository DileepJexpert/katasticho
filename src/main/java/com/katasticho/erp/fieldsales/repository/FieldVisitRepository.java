package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldVisit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FieldVisitRepository extends JpaRepository<FieldVisit, UUID> {

    List<FieldVisit> findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(UUID orgId, UUID routeExecutionId);

    Page<FieldVisit> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId, Pageable pageable);

    Optional<FieldVisit> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);
}
