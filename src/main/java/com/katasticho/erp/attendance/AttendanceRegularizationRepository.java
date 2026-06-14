package com.katasticho.erp.attendance;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AttendanceRegularizationRepository extends JpaRepository<AttendanceRegularization, UUID> {

    Optional<AttendanceRegularization> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<AttendanceRegularization> findByOrgIdAndUserIdAndIsDeletedFalseOrderByWorkDateDesc(
            UUID orgId, UUID userId);

    List<AttendanceRegularization> findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(
            UUID orgId, String status);
}
