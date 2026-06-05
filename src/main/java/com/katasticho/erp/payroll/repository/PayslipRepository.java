package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.Payslip;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PayslipRepository extends JpaRepository<Payslip, UUID> {

    Optional<Payslip> findByIdAndOrgId(UUID id, UUID orgId);

    List<Payslip> findByOrgIdAndPayrollRunId(UUID orgId, UUID payrollRunId);

    Optional<Payslip> findByOrgIdAndPayrollRunIdAndEmployeeId(UUID orgId, UUID payrollRunId, UUID employeeId);
}
