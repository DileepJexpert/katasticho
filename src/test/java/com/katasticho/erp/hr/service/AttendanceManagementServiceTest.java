package com.katasticho.erp.hr.service;

import com.katasticho.erp.attendance.*;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.hr.repository.HolidayRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AttendanceManagementServiceTest {

    @Mock private FieldAttendanceRepository attendanceRepo;
    @Mock private AttendanceRegularizationRepository regRepo;
    @Mock private LeaveRequestRepository leaveRepo;
    @Mock private HolidayRepository holidayRepo;
    @Mock private LeaveManagementService leaveMgmt;
    @Mock private com.katasticho.erp.common.country.CountryAccessService countryAccess;

    private AttendanceManagementService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final LocalDate workDate = LocalDate.of(2026, 5, 4);

    @BeforeEach
    void setUp() {
        service = new AttendanceManagementService(attendanceRepo, regRepo, leaveRepo, holidayRepo, leaveMgmt, countryAccess);
        // India weekend (Sat+Sun) so existing summary assertions hold.
        org.mockito.Mockito.lenient().when(countryAccess.weekendDays())
                .thenReturn(java.util.Set.of(java.time.DayOfWeek.SATURDAY, java.time.DayOfWeek.SUNDAY));
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void approve_writesCorrectedPunchToAttendance() {
        Instant in = Instant.parse("2026-05-04T09:00:00Z");
        Instant out = Instant.parse("2026-05-04T17:00:00Z");
        AttendanceRegularization reg = AttendanceRegularization.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId).workDate(workDate)
                .requestedPunchIn(in).requestedPunchOut(out).status("PENDING").build();
        when(regRepo.findByIdAndOrgIdAndIsDeletedFalse(reg.getId(), orgId)).thenReturn(Optional.of(reg));
        when(attendanceRepo.findByOrgIdAndUserIdAndWorkDate(orgId, userId, workDate))
                .thenReturn(Optional.empty());
        ArgumentCaptor<FieldAttendance> cap = ArgumentCaptor.forClass(FieldAttendance.class);
        when(attendanceRepo.save(cap.capture())).thenAnswer(i -> i.getArgument(0));
        when(regRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        AttendanceRegularization result = service.approve(reg.getId());

        assertEquals("APPROVED", result.getStatus());
        assertEquals(in, cap.getValue().getPunchInAt());
        assertEquals(out, cap.getValue().getPunchOutAt());
    }

    @Test
    void monthlySummary_computesPresentLeaveAndAbsent() {
        LocalDate from = LocalDate.of(2026, 5, 1);
        LocalDate to = LocalDate.of(2026, 5, 31);
        when(leaveMgmt.workingDays(from, to)).thenReturn(new BigDecimal("22"));

        Instant in = Instant.parse("2026-05-04T09:00:00Z");
        Instant out = Instant.parse("2026-05-04T17:00:00Z");   // 8h
        FieldAttendance a1 = FieldAttendance.builder().orgId(orgId).userId(userId)
                .workDate(LocalDate.of(2026, 5, 4)).punchInAt(in).punchOutAt(out).build();
        FieldAttendance a2 = FieldAttendance.builder().orgId(orgId).userId(userId)
                .workDate(LocalDate.of(2026, 5, 5)).punchInAt(in).punchOutAt(out).build();
        FieldAttendance a3 = FieldAttendance.builder().orgId(orgId).userId(userId)
                .workDate(LocalDate.of(2026, 5, 6)).punchInAt(in).build();   // no punch-out
        when(attendanceRepo.findByOrgIdAndUserIdAndWorkDateBetweenOrderByWorkDateDesc(orgId, userId, from, to))
                .thenReturn(List.of(a1, a2, a3));

        LeaveRequest leave = LeaveRequest.builder()
                .orgId(orgId).userId(userId).status("APPROVED")
                .fromDate(LocalDate.of(2026, 5, 11)).toDate(LocalDate.of(2026, 5, 12)).build();
        when(leaveRepo.findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                eq(orgId), eq(userId), any(), eq(to), eq(from))).thenReturn(List.of(leave));
        when(leaveMgmt.workingDays(LocalDate.of(2026, 5, 11), LocalDate.of(2026, 5, 12)))
                .thenReturn(new BigDecimal("2"));
        when(holidayRepo.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(orgId, from, to))
                .thenReturn(List.of());

        Map<String, Object> s = service.monthlySummary(null, from);

        assertEquals(3, s.get("presentDays"));
        assertEquals(0, ((BigDecimal) s.get("leaveDays")).compareTo(new BigDecimal("2")));
        // 22 working - 3 present - 2 leave = 17 absent
        assertEquals(0, ((BigDecimal) s.get("absentDays")).compareTo(new BigDecimal("17")));
        // present 3 + paid leave 2 = 5 payable
        assertEquals(0, ((BigDecimal) s.get("payableDays")).compareTo(new BigDecimal("5")));
        // two 8h days = 16.0h
        assertEquals(0, ((BigDecimal) s.get("totalHours")).compareTo(new BigDecimal("16.0")));
    }
}
