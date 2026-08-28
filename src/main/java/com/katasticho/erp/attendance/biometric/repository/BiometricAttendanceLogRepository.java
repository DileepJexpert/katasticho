package com.katasticho.erp.attendance.biometric.repository;

import com.katasticho.erp.attendance.biometric.entity.BiometricAttendanceLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BiometricAttendanceLogRepository extends JpaRepository<BiometricAttendanceLog, UUID> {

    List<BiometricAttendanceLog> findTop100ByOrgIdAndIsDeletedFalseOrderByPunchTimeDesc(UUID orgId);

    List<BiometricAttendanceLog> findByOrgIdAndPunchTimeBetweenAndIsDeletedFalseOrderByPunchTimeAsc(
            UUID orgId, Instant startTime, Instant endTime);

    List<BiometricAttendanceLog> findByOrgIdAndEmployeeIdAndPunchTimeBetweenAndIsDeletedFalseOrderByPunchTimeAsc(
            UUID orgId, UUID employeeId, Instant startTime, Instant endTime);

    Optional<BiometricAttendanceLog> findFirstByOrgIdAndBiometricPinAndPunchTimeAndIsDeletedFalse(
            UUID orgId, String biometricPin, Instant punchTime);
}
