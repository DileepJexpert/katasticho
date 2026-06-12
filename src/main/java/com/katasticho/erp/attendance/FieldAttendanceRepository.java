package com.katasticho.erp.attendance;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FieldAttendanceRepository extends JpaRepository<FieldAttendance, UUID> {

    Optional<FieldAttendance> findByOrgIdAndUserIdAndWorkDate(UUID orgId, UUID userId, LocalDate workDate);

    List<FieldAttendance> findByOrgIdAndUserIdAndWorkDateBetweenOrderByWorkDateDesc(
            UUID orgId, UUID userId, LocalDate from, LocalDate to);

    List<FieldAttendance> findByOrgIdAndWorkDateOrderByPunchInAt(UUID orgId, LocalDate workDate);
}
