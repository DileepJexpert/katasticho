package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldVisit;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FieldVisitRepository extends JpaRepository<FieldVisit, UUID> {

    List<FieldVisit> findByOrgIdAndRouteExecutionIdAndIsDeletedFalseOrderBySequenceNumber(UUID orgId, UUID routeExecutionId);

    Page<FieldVisit> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId, Pageable pageable);

    Optional<FieldVisit> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Completed visits per contact within a date range (whole org). */
    @Query("""
            SELECT v.contactId, COUNT(v)
            FROM FieldVisit v, RouteExecution e
            WHERE v.routeExecutionId = e.id
              AND v.orgId = :orgId AND v.isDeleted = false
              AND v.status = 'COMPLETED'
              AND e.executionDate BETWEEN :from AND :to
            GROUP BY v.contactId
            """)
    List<Object[]> countCompletedVisitsByContact(
            @Param("orgId") UUID orgId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /** Completed visits per contact within a date range for one salesperson. */
    @Query("""
            SELECT v.contactId, COUNT(v)
            FROM FieldVisit v, RouteExecution e
            WHERE v.routeExecutionId = e.id
              AND v.orgId = :orgId AND v.isDeleted = false
              AND v.status = 'COMPLETED'
              AND e.executionDate BETWEEN :from AND :to
              AND e.salespersonId = :salespersonId
            GROUP BY v.contactId
            """)
    List<Object[]> countCompletedVisitsByContactForSalesperson(
            @Param("orgId") UUID orgId, @Param("from") LocalDate from, @Param("to") LocalDate to,
            @Param("salespersonId") UUID salespersonId);
}
