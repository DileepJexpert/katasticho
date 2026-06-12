package com.katasticho.erp.attendance;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Attendance (GPS-stamped punch in/out, one row per user per day) and a
 * simple leave-request lifecycle. Vertical-neutral and not module-gated —
 * any staff member with app access can punch; managers approve leave.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceService {

    private final FieldAttendanceRepository attendanceRepository;
    private final LeaveRequestRepository leaveRepository;
    private final AppUserRepository appUserRepository;

    // ── Attendance ───────────────────────────────────────────────────────

    @Transactional
    public FieldAttendance punchIn(BigDecimal latitude, BigDecimal longitude, String notes) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        LocalDate today = LocalDate.now();

        FieldAttendance attendance = attendanceRepository
                .findByOrgIdAndUserIdAndWorkDate(orgId, userId, today)
                .orElseGet(() -> FieldAttendance.builder()
                        .orgId(orgId).userId(userId).workDate(today).build());

        if (attendance.getPunchInAt() != null) {
            throw new BusinessException("Already punched in today",
                    "ATT_ALREADY_PUNCHED_IN", HttpStatus.CONFLICT);
        }
        attendance.setPunchInAt(Instant.now());
        attendance.setPunchInLatitude(latitude);
        attendance.setPunchInLongitude(longitude);
        if (notes != null && !notes.isBlank()) attendance.setNotes(notes);
        return attendanceRepository.save(attendance);
    }

    @Transactional
    public FieldAttendance punchOut(BigDecimal latitude, BigDecimal longitude) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        LocalDate today = LocalDate.now();

        FieldAttendance attendance = attendanceRepository
                .findByOrgIdAndUserIdAndWorkDate(orgId, userId, today)
                .orElseThrow(() -> new BusinessException("Punch in first",
                        "ATT_NOT_PUNCHED_IN", HttpStatus.BAD_REQUEST));
        if (attendance.getPunchInAt() == null) {
            throw new BusinessException("Punch in first",
                    "ATT_NOT_PUNCHED_IN", HttpStatus.BAD_REQUEST);
        }
        if (attendance.getPunchOutAt() != null) {
            throw new BusinessException("Already punched out today",
                    "ATT_ALREADY_PUNCHED_OUT", HttpStatus.CONFLICT);
        }
        attendance.setPunchOutAt(Instant.now());
        attendance.setPunchOutLatitude(latitude);
        attendance.setPunchOutLongitude(longitude);
        return attendanceRepository.save(attendance);
    }

    @Transactional(readOnly = true)
    public Optional<FieldAttendance> today() {
        return attendanceRepository.findByOrgIdAndUserIdAndWorkDate(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId(), LocalDate.now());
    }

    @Transactional(readOnly = true)
    public List<FieldAttendance> myMonth(LocalDate month) {
        LocalDate from = month.withDayOfMonth(1);
        return attendanceRepository.findByOrgIdAndUserIdAndWorkDateBetweenOrderByWorkDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId(),
                from, from.plusMonths(1).minusDays(1));
    }

    /** Team attendance for a date with resolved user names (manager view). */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> teamOnDate(LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<FieldAttendance> rows =
                attendanceRepository.findByOrgIdAndWorkDateOrderByPunchInAt(orgId, date);
        Map<UUID, String> names = appUserRepository
                .findAllById(rows.stream().map(FieldAttendance::getUserId).collect(Collectors.toSet()))
                .stream()
                .collect(Collectors.toMap(AppUser::getId,
                        u -> u.getFullName() != null ? u.getFullName() : ""));

        List<Map<String, Object>> result = new ArrayList<>();
        for (FieldAttendance a : rows) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", a.getUserId());
            row.put("userName", names.getOrDefault(a.getUserId(), ""));
            row.put("punchInAt", a.getPunchInAt());
            row.put("punchOutAt", a.getPunchOutAt());
            row.put("punchInLatitude", a.getPunchInLatitude());
            row.put("punchInLongitude", a.getPunchInLongitude());
            Long minutes = a.getPunchInAt() != null && a.getPunchOutAt() != null
                    ? java.time.Duration.between(a.getPunchInAt(), a.getPunchOutAt()).toMinutes()
                    : null;
            row.put("workedMinutes", minutes);
            result.add(row);
        }
        return result;
    }

    // ── Leave ────────────────────────────────────────────────────────────

    @Transactional
    public LeaveRequest applyLeave(LocalDate from, LocalDate to, String leaveType, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        if (from == null || to == null || to.isBefore(from)) {
            throw new BusinessException("Invalid leave date range",
                    "LEAVE_INVALID_RANGE", HttpStatus.BAD_REQUEST);
        }
        boolean overlaps = !leaveRepository
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, userId, List.of("PENDING", "APPROVED"), to, from)
                .isEmpty();
        if (overlaps) {
            throw new BusinessException("You already have leave overlapping these dates",
                    "LEAVE_OVERLAPS", HttpStatus.CONFLICT);
        }

        return leaveRepository.save(LeaveRequest.builder()
                .orgId(orgId).userId(userId)
                .fromDate(from).toDate(to)
                .leaveType(leaveType != null ? leaveType : "CASUAL")
                .reason(reason)
                .build());
    }

    @Transactional
    public LeaveRequest cancelLeave(UUID leaveId) {
        LeaveRequest leave = loadLeave(leaveId);
        if (!leave.getUserId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException("Only the requester can cancel a leave",
                    "LEAVE_NOT_OWNER", HttpStatus.FORBIDDEN);
        }
        if (!"PENDING".equals(leave.getStatus())) {
            throw new BusinessException("Only pending leave can be cancelled",
                    "LEAVE_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }
        leave.setStatus("CANCELLED");
        return leaveRepository.save(leave);
    }

    @Transactional
    public LeaveRequest approveLeave(UUID leaveId) {
        LeaveRequest leave = loadPendingLeave(leaveId);
        ensureNotSelfApproval(leave.getUserId());
        leave.setStatus("APPROVED");
        leave.setApprovedBy(TenantContext.getCurrentUserId());
        leave.setApprovedAt(Instant.now());
        return leaveRepository.save(leave);
    }

    @Transactional
    public LeaveRequest rejectLeave(UUID leaveId, String reason) {
        LeaveRequest leave = loadPendingLeave(leaveId);
        ensureNotSelfApproval(leave.getUserId());
        leave.setStatus("REJECTED");
        leave.setRejectionReason(reason);
        return leaveRepository.save(leave);
    }

    @Transactional(readOnly = true)
    public List<LeaveRequest> myLeaves() {
        return leaveRepository.findByOrgIdAndUserIdAndIsDeletedFalseOrderByFromDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    @Transactional(readOnly = true)
    public List<LeaveRequest> pendingLeaves() {
        return leaveRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(
                TenantContext.getCurrentOrgId(), "PENDING");
    }

    private LeaveRequest loadLeave(UUID leaveId) {
        return leaveRepository.findByIdAndOrgIdAndIsDeletedFalse(
                        leaveId, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("LeaveRequest", leaveId));
    }

    private LeaveRequest loadPendingLeave(UUID leaveId) {
        LeaveRequest leave = loadLeave(leaveId);
        if (!"PENDING".equals(leave.getStatus())) {
            throw new BusinessException(
                    "Leave must be PENDING to decide, current: " + leave.getStatus(),
                    "LEAVE_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }
        return leave;
    }

    private void ensureNotSelfApproval(UUID requesterId) {
        if (requesterId.equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException("You cannot approve or reject your own leave",
                    "LEAVE_SELF_APPROVAL_FORBIDDEN", HttpStatus.FORBIDDEN);
        }
    }
}
