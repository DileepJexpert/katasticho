package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldSalesExecutionAudit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FieldSalesExecutionAuditRepository extends JpaRepository<FieldSalesExecutionAudit, UUID> {

    List<FieldSalesExecutionAudit> findByOrgIdAndExecutionId(UUID orgId, UUID executionId);

    List<FieldSalesExecutionAudit> findByOrgIdAndSalespersonId(UUID orgId, UUID salespersonId);
}
