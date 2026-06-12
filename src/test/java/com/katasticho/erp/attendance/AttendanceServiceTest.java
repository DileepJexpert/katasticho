package com.katasticho.erp.attendance;

import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AttendanceServiceTest {

    @Mock private FieldAttendanceRepository attendanceRepo;
    @Mock private LeaveRequestRepository leaveRepo;
    @Mock private AppUserRepository appUserRepo;

    private AttendanceService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID managerId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new AttendanceService(attendanceRepo, leaveRepo, appUserRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void punchIn_recordsTimeAndGps() {
        when(attendanceRepo.findByOrgIdAndUserIdAndWorkDate(eq(orgId), eq(userId), any()))
                .thenReturn(Optional.empty());
        when(attendanceRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldAttendance a = service.punchIn(
                new BigDecimal("28.6139"), new BigDecimal("77.2090"), null);

        assertNotNull(a.getPunchInAt());
        assertEquals(new BigDecimal("28.6139"), a.getPunchInLatitude());
        assertEquals(LocalDate.now(), a.getWorkDate());
    }

    @Test
    void punchIn_twice_throws() {
        FieldAttendance existing = FieldAttendance.builder()
                .orgId(orgId).userId(userId).workDate(LocalDate.now())
                .punchInAt(Instant.now()).build();
        when(attendanceRepo.findByOrgIdAndUserIdAndWorkDate(eq(orgId), eq(userId), any()))
                .thenReturn(Optional.of(existing));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.punchIn(null, null, null));
        assertEquals("ATT_ALREADY_PUNCHED_IN", ex.getErrorCode());
    }

    @Test
    void punchOut_withoutPunchIn_throws() {
        when(attendanceRepo.findByOrgIdAndUserIdAndWorkDate(eq(orgId), eq(userId), any()))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.punchOut(null, null));
        assertEquals("ATT_NOT_PUNCHED_IN", ex.getErrorCode());
    }

    @Test
    void punchOut_afterPunchIn_succeeds() {
        FieldAttendance existing = FieldAttendance.builder()
                .orgId(orgId).userId(userId).workDate(LocalDate.now())
                .punchInAt(Instant.now().minusSeconds(3600)).build();
        when(attendanceRepo.findByOrgIdAndUserIdAndWorkDate(eq(orgId), eq(userId), any()))
                .thenReturn(Optional.of(existing));
        when(attendanceRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldAttendance a = service.punchOut(new BigDecimal("28.7"), new BigDecimal("77.2"));

        assertNotNull(a.getPunchOutAt());
        assertEquals(new BigDecimal("28.7"), a.getPunchOutLatitude());
    }

    @Test
    void applyLeave_overlapping_throws() {
        when(leaveRepo.findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                eq(orgId), eq(userId), any(), any(), any()))
                .thenReturn(List.of(LeaveRequest.builder().build()));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.applyLeave(LocalDate.now(), LocalDate.now().plusDays(2), "CASUAL", null));
        assertEquals("LEAVE_OVERLAPS", ex.getErrorCode());
    }

    @Test
    void applyLeave_validRange_succeeds() {
        when(leaveRepo.findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                eq(orgId), eq(userId), any(), any(), any())).thenReturn(List.of());
        when(leaveRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        LeaveRequest leave = service.applyLeave(
                LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 3), "SICK", "Fever");

        assertEquals("PENDING", leave.getStatus());
        assertEquals("SICK", leave.getLeaveType());
    }

    @Test
    void approveLeave_own_throws() {
        LeaveRequest leave = LeaveRequest.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId)
                .fromDate(LocalDate.now()).toDate(LocalDate.now())
                .status("PENDING").build();
        when(leaveRepo.findByIdAndOrgIdAndIsDeletedFalse(leave.getId(), orgId))
                .thenReturn(Optional.of(leave));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approveLeave(leave.getId()));
        assertEquals("LEAVE_SELF_APPROVAL_FORBIDDEN", ex.getErrorCode());
    }

    @Test
    void approveLeave_byManager_succeeds() {
        LeaveRequest leave = LeaveRequest.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(managerId)
                .fromDate(LocalDate.now()).toDate(LocalDate.now())
                .status("PENDING").build();
        when(leaveRepo.findByIdAndOrgIdAndIsDeletedFalse(leave.getId(), orgId))
                .thenReturn(Optional.of(leave));
        when(leaveRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        LeaveRequest result = service.approveLeave(leave.getId());

        assertEquals("APPROVED", result.getStatus());
        assertEquals(userId, result.getApprovedBy());
    }
}
