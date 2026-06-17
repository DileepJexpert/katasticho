package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.EmployeeEducation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeEducationRepository extends JpaRepository<EmployeeEducation, UUID> {

    Optional<EmployeeEducation> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<EmployeeEducation> findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByStartYearDesc(
            UUID orgId, UUID employeeId);
}
