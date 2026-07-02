package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.Employee;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, UUID> {

    Optional<Employee> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<Employee> findByOrgIdAndIsDeletedFalseAndIdIn(UUID orgId, Collection<UUID> ids);

    Optional<Employee> findByOrgIdAndUserIdAndIsDeletedFalse(UUID orgId, UUID userId);

    Page<Employee> findByOrgIdAndIsDeletedFalseOrderByFullNameAsc(UUID orgId, Pageable pageable);

    List<Employee> findByOrgIdAndIsDeletedFalseAndEmploymentStatus(UUID orgId, String status);

    /** All non-deleted employees — gratuity accrual filters by service window, not current status. */
    List<Employee> findByOrgIdAndIsDeletedFalse(UUID orgId);

    Optional<Employee> findByOrgIdAndEmployeeCodeAndIsDeletedFalse(UUID orgId, String employeeCode);
}
