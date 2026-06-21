package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.EmployeeTaxDeclaration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeTaxDeclarationRepository extends JpaRepository<EmployeeTaxDeclaration, UUID> {

    Optional<EmployeeTaxDeclaration> findByOrgIdAndEmployeeIdAndFiscalYearAndIsDeletedFalse(
            UUID orgId, UUID employeeId, String fiscalYear);

    Optional<EmployeeTaxDeclaration> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<EmployeeTaxDeclaration> findByOrgIdAndFiscalYearAndIsDeletedFalseOrderByCreatedAtDesc(
            UUID orgId, String fiscalYear);
}
