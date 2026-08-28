package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldSalesAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FieldSalesAssignmentRepository extends JpaRepository<FieldSalesAssignment, UUID> {

    Optional<FieldSalesAssignment> findByIdAndOrgId(UUID id, UUID orgId);

    List<FieldSalesAssignment> findByOrgIdAndSalespersonIdAndIsActiveTrue(UUID orgId, UUID salespersonId);

    List<FieldSalesAssignment> findByOrgIdAndRouteIdAndIsActiveTrue(UUID orgId, UUID routeId);

    List<FieldSalesAssignment> findByOrgIdAndSalespersonIdAndRouteIdAndIsActiveTrue(UUID orgId, UUID salespersonId, UUID routeId);

    List<FieldSalesAssignment> findByOrgIdAndIsActiveTrue(UUID orgId);

    List<FieldSalesAssignment> findByOrgId(UUID orgId);

    @Query("SELECT a FROM FieldSalesAssignment a WHERE a.orgId = :orgId AND a.isActive = true AND a.effectiveFrom <= :date AND (a.effectiveTo IS NULL OR a.effectiveTo >= :date)")
    List<FieldSalesAssignment> findActiveAssignmentsOnDate(
            @Param("orgId") UUID orgId,
            @Param("date") LocalDate date);

    @Query("SELECT a FROM FieldSalesAssignment a WHERE a.orgId = :orgId AND a.salespersonId = :salespersonId AND a.routeId = :routeId AND a.isActive = true AND a.effectiveFrom <= :date AND (a.effectiveTo IS NULL OR a.effectiveTo >= :date)")
    List<FieldSalesAssignment> findActiveAssignmentsForSalespersonAndRouteOnDate(
            @Param("orgId") UUID orgId,
            @Param("salespersonId") UUID salespersonId,
            @Param("routeId") UUID routeId,
            @Param("date") LocalDate date);

    @Query("SELECT a FROM FieldSalesAssignment a WHERE a.orgId = :orgId AND a.salespersonId = :salespersonId AND a.isActive = true AND a.effectiveFrom <= :date AND (a.effectiveTo IS NULL OR a.effectiveTo >= :date)")
    List<FieldSalesAssignment> findActiveAssignmentsForSalespersonOnDate(
            @Param("orgId") UUID orgId,
            @Param("salespersonId") UUID salespersonId,
            @Param("date") LocalDate date);
}
