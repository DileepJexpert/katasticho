package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldSalesAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FieldSalesAssignmentRepository extends JpaRepository<FieldSalesAssignment, UUID> {

    List<FieldSalesAssignment> findByOrgIdAndSalespersonIdAndIsActiveTrue(UUID orgId, UUID salespersonId);

    List<FieldSalesAssignment> findByOrgIdAndRouteIdAndIsActiveTrue(UUID orgId, UUID routeId);

    List<FieldSalesAssignment> findByOrgIdAndIsActiveTrue(UUID orgId);
}
