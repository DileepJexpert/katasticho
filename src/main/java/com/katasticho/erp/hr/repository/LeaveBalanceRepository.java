package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.LeaveBalance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LeaveBalanceRepository extends JpaRepository<LeaveBalance, UUID> {

    Optional<LeaveBalance> findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(
            UUID orgId, UUID userId, UUID leaveTypeId, int year);

    /** Pessimistic-write variant so concurrent leave approvals serialise on the
     *  balance row and can't both consume it past entitlement (lost update). */
    @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM LeaveBalance b WHERE b.orgId = :orgId AND b.userId = :userId "
            + "AND b.leaveTypeId = :leaveTypeId AND b.year = :year AND b.isDeleted = false")
    Optional<LeaveBalance> findForUpdate(@Param("orgId") UUID orgId, @Param("userId") UUID userId,
                                         @Param("leaveTypeId") UUID leaveTypeId, @Param("year") int year);

    List<LeaveBalance> findByOrgIdAndUserIdAndYearAndIsDeletedFalse(UUID orgId, UUID userId, int year);
}
