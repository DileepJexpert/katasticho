package com.katasticho.erp.hr.service;

import com.katasticho.erp.attendance.AttendanceRegularization;
import com.katasticho.erp.attendance.AttendanceRegularizationRepository;
import com.katasticho.erp.attendance.LeaveRequest;
import com.katasticho.erp.attendance.LeaveRequestRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.hr.entity.EmployeeDocument;
import com.katasticho.erp.hr.entity.HrTicket;
import com.katasticho.erp.hr.entity.TimesheetEntry;
import com.katasticho.erp.hr.repository.EmployeeDocumentRepository;
import com.katasticho.erp.hr.repository.HrTicketRepository;
import com.katasticho.erp.hr.repository.TimesheetEntryRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HrAnalyticsServiceTest {

    @Mock private EmployeeRepository employeeRepo;
    @Mock private LeaveRequestRepository leaveRepo;
    @Mock private HrTicketRepository ticketRepo;
    @Mock private EmployeeDocumentRepository docRepo;
    @Mock private TimesheetEntryRepository tsRepo;
    @Mock private AttendanceRegularizationRepository regRepo;

    private HrAnalyticsService service;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new HrAnalyticsService(employeeRepo, leaveRepo, ticketRepo, docRepo, tsRepo, regRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    @SuppressWarnings("unchecked")
    void dashboard_rollsUpCountsAndDepartments() {
        final LocalDate today = LocalDate.now();
        when(employeeRepo.findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE"))
                .thenReturn(List.of(
                        Employee.builder().department("Sales").build(),
                        Employee.builder().department("Sales").build(),
                        Employee.builder().build()));
        when(leaveRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(orgId, "APPROVED"))
                .thenReturn(List.of(
                        LeaveRequest.builder().fromDate(today.minusDays(1)).toDate(today.plusDays(1)).build(),
                        LeaveRequest.builder().fromDate(today.minusDays(10)).toDate(today.minusDays(8)).build()));
        when(leaveRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(orgId, "PENDING"))
                .thenReturn(List.of(LeaveRequest.builder().build(), LeaveRequest.builder().build()));
        when(regRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(orgId, "PENDING"))
                .thenReturn(List.of(AttendanceRegularization.builder().build()));
        when(tsRepo.findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(orgId, "SUBMITTED"))
                .thenReturn(List.of(TimesheetEntry.builder().build(), TimesheetEntry.builder().build(),
                        TimesheetEntry.builder().build(), TimesheetEntry.builder().build()));
        when(ticketRepo.findByOrgIdAndStatusInAndIsDeletedFalseOrderByCreatedAtDesc(eq(orgId), any()))
                .thenReturn(List.of(HrTicket.builder().subject("a").build(),
                        HrTicket.builder().subject("b").build()));
        when(docRepo.findByOrgIdAndExpiryDateLessThanEqualAndIsDeletedFalseOrderByExpiryDateAsc(eq(orgId), any()))
                .thenReturn(List.of(EmployeeDocument.builder().title("x").build()));

        Map<String, Object> d = service.dashboard();

        assertEquals(3, d.get("headcount"));
        assertEquals(1L, d.get("onLeaveToday"));
        assertEquals(2, d.get("pendingLeaves"));
        assertEquals(1, d.get("pendingRegularizations"));
        assertEquals(4, d.get("pendingTimesheets"));
        assertEquals(2, d.get("openTickets"));
        assertEquals(1, d.get("documentsExpiringIn30Days"));
        Map<String, Long> byDept = (Map<String, Long>) d.get("byDepartment");
        assertEquals(2L, byDept.get("Sales"));
        assertEquals(1L, byDept.get("Unassigned"));
    }
}
