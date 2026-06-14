package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.LeaveBalance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LeaveBalanceRepository extends JpaRepository<LeaveBalance, UUID> {

    Optional<LeaveBalance> findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(
            UUID orgId, UUID userId, UUID leaveTypeId, int year);

    List<LeaveBalance> findByOrgIdAndUserIdAndYearAndIsDeletedFalse(UUID orgId, UUID userId, int year);
}
