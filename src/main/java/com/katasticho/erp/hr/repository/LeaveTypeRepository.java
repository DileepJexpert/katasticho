package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.LeaveType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LeaveTypeRepository extends JpaRepository<LeaveType, UUID> {

    Optional<LeaveType> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<LeaveType> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    List<LeaveType> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId);

    List<LeaveType> findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByNameAsc(UUID orgId);
}
