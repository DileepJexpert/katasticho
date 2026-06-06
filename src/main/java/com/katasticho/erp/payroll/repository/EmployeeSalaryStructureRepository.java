package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.EmployeeSalaryStructure;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeSalaryStructureRepository extends JpaRepository<EmployeeSalaryStructure, UUID> {

    Optional<EmployeeSalaryStructure> findByIdAndOrgId(UUID id, UUID orgId);

    List<EmployeeSalaryStructure> findByOrgIdAndEmployeeIdAndStatusOrderByEffectiveFromDesc(
            UUID orgId, UUID employeeId, String status);

    /**
     * Find the current active salary structure for an employee.
     * Returns the most recent structure whose effective period covers today.
     */
    @Query("SELECT s FROM EmployeeSalaryStructure s WHERE s.orgId = :orgId " +
            "AND s.employeeId = :employeeId AND s.status = 'ACTIVE' " +
            "AND (s.effectiveTo IS NULL OR s.effectiveTo >= CURRENT_DATE) " +
            "ORDER BY s.effectiveFrom DESC")
    Optional<EmployeeSalaryStructure> findCurrentActive(UUID orgId, UUID employeeId);
}
