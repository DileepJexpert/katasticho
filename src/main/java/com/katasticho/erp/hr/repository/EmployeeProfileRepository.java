package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.EmployeeProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface EmployeeProfileRepository extends JpaRepository<EmployeeProfile, UUID> {

    Optional<EmployeeProfile> findByOrgIdAndUserIdAndIsDeletedFalse(UUID orgId, UUID userId);
}
