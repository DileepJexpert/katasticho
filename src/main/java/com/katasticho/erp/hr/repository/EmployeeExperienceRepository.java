package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.EmployeeExperience;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeExperienceRepository extends JpaRepository<EmployeeExperience, UUID> {

    Optional<EmployeeExperience> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<EmployeeExperience> findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByFromDateDesc(
            UUID orgId, UUID employeeId);
}
