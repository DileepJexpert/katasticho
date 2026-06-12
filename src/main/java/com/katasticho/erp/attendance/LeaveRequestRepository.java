package com.katasticho.erp.attendance;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, UUID> {

    Optional<LeaveRequest> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<LeaveRequest> findByOrgIdAndUserIdAndIsDeletedFalseOrderByFromDateDesc(UUID orgId, UUID userId);

    List<LeaveRequest> findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(UUID orgId, String status);

    /** Overlapping non-rejected leaves for the user. */
    List<LeaveRequest> findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
            UUID orgId, UUID userId, List<String> statuses, LocalDate to, LocalDate from);
}
