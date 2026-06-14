package com.katasticho.erp.hr.service;

import com.katasticho.erp.attendance.AttendanceRegularizationRepository;
import com.katasticho.erp.attendance.LeaveRequest;
import com.katasticho.erp.attendance.LeaveRequestRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.hr.repository.EmployeeDocumentRepository;
import com.katasticho.erp.hr.repository.HrTicketRepository;
import com.katasticho.erp.hr.repository.TimesheetEntryRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;

/**
 * HR Analytics — Core HR module 8. A read-only snapshot dashboard that rolls up
 * the data already captured by the other Core HR modules (headcount, leave,
 * attendance, timesheets, help desk, document expiry).
 */
@Service
@RequiredArgsConstructor
public class HrAnalyticsService {

    private final EmployeeRepository employeeRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final HrTicketRepository ticketRepository;
    private final EmployeeDocumentRepository documentRepository;
    private final TimesheetEntryRepository timesheetRepository;
    private final AttendanceRegularizationRepository regularizationRepository;

    @Transactional(readOnly = true)
    public Map<String, Object> dashboard() {
        UUID orgId = TenantContext.getCurrentOrgId();
        LocalDate today = LocalDate.now();

        List<Employee> active = employeeRepository
                .findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE");
        Map<String, Long> byDept = new LinkedHashMap<>();
        for (Employee e : active) {
            String dept = e.getDepartment() != null && !e.getDepartment().isBlank()
                    ? e.getDepartment() : "Unassigned";
            byDept.merge(dept, 1L, Long::sum);
        }

        long onLeaveToday = leaveRequestRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(orgId, "APPROVED")
                .stream()
                .filter(l -> !today.isBefore(l.getFromDate()) && !today.isAfter(l.getToDate()))
                .count();

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("headcount", active.size());
        out.put("byDepartment", byDept);
        out.put("onLeaveToday", onLeaveToday);
        out.put("pendingLeaves", leaveRequestRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(orgId, "PENDING").size());
        out.put("pendingRegularizations", regularizationRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(orgId, "PENDING").size());
        out.put("pendingTimesheets", timesheetRepository
                .findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(orgId, "SUBMITTED").size());
        out.put("openTickets", ticketRepository
                .findByOrgIdAndStatusInAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, List.of("OPEN", "IN_PROGRESS")).size());
        out.put("documentsExpiringIn30Days", documentRepository
                .findByOrgIdAndExpiryDateLessThanEqualAndIsDeletedFalseOrderByExpiryDateAsc(
                        orgId, today.plusDays(30)).size());
        return out;
    }
}
