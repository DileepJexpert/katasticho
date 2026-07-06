package com.katasticho.erp.hr.service;

import com.katasticho.erp.attendance.LeaveRequest;
import com.katasticho.erp.attendance.LeaveRequestRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.Holiday;
import com.katasticho.erp.hr.entity.LeaveBalance;
import com.katasticho.erp.hr.entity.LeaveType;
import com.katasticho.erp.hr.repository.HolidayRepository;
import com.katasticho.erp.hr.repository.LeaveBalanceRepository;
import com.katasticho.erp.hr.repository.LeaveTypeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LeaveManagementServiceTest {

    @Mock private LeaveTypeRepository typeRepo;
    @Mock private HolidayRepository holidayRepo;
    @Mock private LeaveBalanceRepository balanceRepo;
    @Mock private LeaveRequestRepository leaveRepo;
    @Mock private com.katasticho.erp.common.country.CountryAccessService countryAccess;

    private LeaveManagementService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID typeId = UUID.randomUUID();

    // 2026-05-04 is a Monday
    private final LocalDate mon = LocalDate.of(2026, 5, 4);
    private final LocalDate tue = LocalDate.of(2026, 5, 5);

    @BeforeEach
    void setUp() {
        service = new LeaveManagementService(typeRepo, holidayRepo, balanceRepo, leaveRepo, countryAccess);
        // India weekend (Sat+Sun) so existing working-day assertions hold.
        org.mockito.Mockito.lenient().when(countryAccess.weekendDays())
                .thenReturn(java.util.Set.of(java.time.DayOfWeek.SATURDAY, java.time.DayOfWeek.SUNDAY));
        // Approval/adjustment now pessimistic-locks the balance row; delegate the
        // locked finder to the plain finder the tests stub.
        org.mockito.Mockito.lenient().when(balanceRepo.findForUpdate(
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyInt()))
                .thenAnswer(inv -> balanceRepo.findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(
                        inv.getArgument(0), inv.getArgument(1), inv.getArgument(2), inv.getArgument(3)));
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private LeaveType type(boolean paid, boolean requiresApproval, String quota) {
        return LeaveType.builder()
                .id(typeId).orgId(orgId).code("CL").name("Casual")
                .paid(paid).annualQuota(new BigDecimal(quota)).accrualMethod("ANNUAL")
                .requiresApproval(requiresApproval).active(true).build();
    }

    private void noOverlap() {
        when(leaveRepo.findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                any(), any(), any(), any(), any())).thenReturn(List.of());
    }

    @Test
    void workingDays_excludesWeekendsAndHolidays() {
        // Mon 4 -> Sun 10, with a holiday on Wed 6 -> Mon,Tue,Thu,Fri = 4
        when(holidayRepo.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
                eq(orgId), any(), any()))
                .thenReturn(List.of(Holiday.builder().holidayDate(LocalDate.of(2026, 5, 6)).build()));

        BigDecimal days = service.workingDays(mon, LocalDate.of(2026, 5, 10));

        assertEquals(0, days.compareTo(new BigDecimal("4")));
    }

    @Test
    void workingDays_omanWeekend_treatsFridayAsOff() {
        // Oman's weekend is Fri+Sat, so a lone Friday is a non-working day there,
        // whereas in India (Sat+Sun) the same Friday counts as a working day.
        when(holidayRepo.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
                eq(orgId), any(), any())).thenReturn(List.of());
        when(countryAccess.weekendDays())
                .thenReturn(java.util.Set.of(java.time.DayOfWeek.FRIDAY, java.time.DayOfWeek.SATURDAY));

        LocalDate fri = LocalDate.of(2026, 5, 8); // a Friday
        assertEquals(0, service.workingDays(fri, fri).compareTo(BigDecimal.ZERO));
    }

    @Test
    void applyLeave_paidInsufficientBalance_throws() {
        when(typeRepo.findByIdAndOrgIdAndIsDeletedFalse(typeId, orgId))
                .thenReturn(Optional.of(type(true, true, "12")));
        when(holidayRepo.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
                eq(orgId), any(), any())).thenReturn(List.of());
        noOverlap();
        when(balanceRepo.findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(orgId, userId, typeId, 2026))
                .thenReturn(Optional.of(LeaveBalance.builder()
                        .orgId(orgId).userId(userId).leaveTypeId(typeId).year(2026)
                        .entitled(new BigDecimal("1")).used(BigDecimal.ZERO).build()));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.applyLeave(typeId, mon, tue, "trip"));  // 2 working days vs 1 available
        assertEquals("HR_LEAVE_INSUFFICIENT_BALANCE", ex.getErrorCode());
    }

    @Test
    void applyLeave_autoApprovePaid_deductsBalanceAndApproves() {
        when(typeRepo.findByIdAndOrgIdAndIsDeletedFalse(typeId, orgId))
                .thenReturn(Optional.of(type(true, false, "12")));   // requiresApproval = false
        when(holidayRepo.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
                eq(orgId), any(), any())).thenReturn(List.of());
        noOverlap();
        LeaveBalance bal = LeaveBalance.builder().orgId(orgId).userId(userId).leaveTypeId(typeId)
                .year(2026).entitled(new BigDecimal("12")).used(BigDecimal.ZERO).build();
        when(balanceRepo.findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(orgId, userId, typeId, 2026))
                .thenReturn(Optional.of(bal));
        when(balanceRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(leaveRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        LeaveRequest req = service.applyLeave(typeId, mon, tue, "trip");

        assertEquals("APPROVED", req.getStatus());
        assertEquals("CL", req.getLeaveType());
        assertEquals(0, req.getWorkingDays().compareTo(new BigDecimal("2")));
        assertEquals(0, bal.getUsed().compareTo(new BigDecimal("2")));   // deducted
    }

    @Test
    void applyLeave_unpaid_marksUnpaidNoBalance() {
        when(typeRepo.findByIdAndOrgIdAndIsDeletedFalse(typeId, orgId))
                .thenReturn(Optional.of(type(false, true, "0")));
        when(holidayRepo.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
                eq(orgId), any(), any())).thenReturn(List.of());
        noOverlap();
        when(leaveRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        LeaveRequest req = service.applyLeave(typeId, mon, tue, "personal");

        assertEquals("PENDING", req.getStatus());
        assertEquals("UNPAID", req.getLeaveType());
        verify(balanceRepo, never()).save(any());
    }

    @Test
    void approveLeave_deductsBalance() {
        LeaveRequest req = LeaveRequest.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId)
                .fromDate(mon).toDate(tue).status("PENDING")
                .leaveType("CL").leaveTypeId(typeId).workingDays(new BigDecimal("2"))
                .build();
        when(leaveRepo.findByIdAndOrgIdAndIsDeletedFalse(req.getId(), orgId)).thenReturn(Optional.of(req));
        when(typeRepo.findByIdAndOrgIdAndIsDeletedFalse(typeId, orgId))
                .thenReturn(Optional.of(type(true, true, "12")));
        LeaveBalance bal = LeaveBalance.builder().orgId(orgId).userId(userId).leaveTypeId(typeId)
                .year(2026).entitled(new BigDecimal("12")).used(BigDecimal.ZERO).build();
        when(balanceRepo.findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(orgId, userId, typeId, 2026))
                .thenReturn(Optional.of(bal));
        ArgumentCaptor<LeaveBalance> cap = ArgumentCaptor.forClass(LeaveBalance.class);
        when(balanceRepo.save(cap.capture())).thenAnswer(inv -> inv.getArgument(0));
        when(leaveRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        LeaveRequest result = service.approveLeave(req.getId());

        assertEquals("APPROVED", result.getStatus());
        assertEquals(0, cap.getValue().getUsed().compareTo(new BigDecimal("2")));
    }

    @Test
    void approveLeave_exceedsRemainingBalance_throws() {
        // Two disjoint PENDING requests both pass the apply-time check (balance
        // untouched until approval); the second approval must be rejected once the
        // first has consumed the balance.
        LeaveRequest req = LeaveRequest.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId)
                .fromDate(mon).toDate(tue).status("PENDING")
                .leaveType("CL").leaveTypeId(typeId).workingDays(new BigDecimal("2"))
                .build();
        when(leaveRepo.findByIdAndOrgIdAndIsDeletedFalse(req.getId(), orgId)).thenReturn(Optional.of(req));
        when(typeRepo.findByIdAndOrgIdAndIsDeletedFalse(typeId, orgId))
                .thenReturn(Optional.of(type(true, true, "12")));
        // Balance already fully used (entitled 12, used 11 → available 1 < 2).
        LeaveBalance bal = LeaveBalance.builder().orgId(orgId).userId(userId).leaveTypeId(typeId)
                .year(2026).entitled(new BigDecimal("12")).used(new BigDecimal("11")).build();
        when(balanceRepo.findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(orgId, userId, typeId, 2026))
                .thenReturn(Optional.of(bal));

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.approveLeave(req.getId()));
        assertEquals("HR_LEAVE_INSUFFICIENT_BALANCE", ex.getErrorCode());
        verify(balanceRepo, never()).save(any());
    }

    @Test
    void cancelLeave_byNonOwner_throwsAndDoesNotRestoreBalance() {
        LeaveRequest req = LeaveRequest.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(UUID.randomUUID()) // owned by someone else
                .fromDate(mon).toDate(tue).status("APPROVED")
                .leaveType("CL").leaveTypeId(typeId).workingDays(new BigDecimal("2"))
                .build();
        when(leaveRepo.findByIdAndOrgIdAndIsDeletedFalse(req.getId(), orgId)).thenReturn(Optional.of(req));
        TenantContext.setCurrentRole("OPERATOR"); // caller is not the owner, not admin

        var ex = assertThrows(com.katasticho.erp.common.exception.BusinessException.class,
                () -> service.cancelLeave(req.getId()));
        assertEquals("LEAVE_NOT_OWNER", ex.getErrorCode());
        assertEquals("APPROVED", req.getStatus());
        verify(balanceRepo, never()).save(any());
    }
}
