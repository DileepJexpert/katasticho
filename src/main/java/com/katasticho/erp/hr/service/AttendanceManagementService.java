package com.katasticho.erp.hr.service;

import com.katasticho.erp.attendance.*;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.repository.HolidayRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * HR Attendance management — Core HR module 2. Attendance regularization
 * (employee requests a punch correction; a manager approves and the corrected
 * punch is written to the day's row) plus the monthly attendance summary
 * (present / leave / holiday / absent / hours) computed from punches, approved
 * leave and the holiday calendar — the input payroll needs for paid days.
 */
@Service
@RequiredArgsConstructor
public class AttendanceManagementService {

    private final FieldAttendanceRepository attendanceRepository;
    private final AttendanceRegularizationRepository regularizationRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final HolidayRepository holidayRepository;
    private final LeaveManagementService leaveManagementService;
    private final com.katasticho.erp.common.country.CountryAccessService countryAccessService;

    // ── Regularization ───────────────────────────────────────────────────

    @Transactional
    public AttendanceRegularization request(LocalDate workDate, Instant punchIn, Instant punchOut, String reason) {
        if (workDate == null || (punchIn == null && punchOut == null)) {
            throw new BusinessException("A work date and at least one punch time are required",
                    "HR_REG_INVALID", org.springframework.http.HttpStatus.BAD_REQUEST);
        }
        return regularizationRepository.save(AttendanceRegularization.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .userId(TenantContext.getCurrentUserId())
                .workDate(workDate).requestedPunchIn(punchIn).requestedPunchOut(punchOut)
                .reason(reason).status("PENDING")
                .build());
    }

    @Transactional
    public AttendanceRegularization approve(UUID id) {
        AttendanceRegularization reg = loadPending(id);
        reg.setStatus("APPROVED");
        reg.setApprovedBy(TenantContext.getCurrentUserId());
        reg.setDecidedAt(Instant.now());

        // Write the corrected punch onto the day's attendance row.
        FieldAttendance att = attendanceRepository
                .findByOrgIdAndUserIdAndWorkDate(reg.getOrgId(), reg.getUserId(), reg.getWorkDate())
                .orElseGet(() -> FieldAttendance.builder()
                        .orgId(reg.getOrgId()).userId(reg.getUserId()).workDate(reg.getWorkDate())
                        .build());
        if (reg.getRequestedPunchIn() != null) att.setPunchInAt(reg.getRequestedPunchIn());
        if (reg.getRequestedPunchOut() != null) att.setPunchOutAt(reg.getRequestedPunchOut());
        att.setNotes(appendNote(att.getNotes(), "Regularized"));
        attendanceRepository.save(att);

        return regularizationRepository.save(reg);
    }

    @Transactional
    public AttendanceRegularization reject(UUID id, String reason) {
        AttendanceRegularization reg = loadPending(id);
        reg.setStatus("REJECTED");
        reg.setRejectionReason(reason);
        reg.setDecidedAt(Instant.now());
        return regularizationRepository.save(reg);
    }

    @Transactional(readOnly = true)
    public List<AttendanceRegularization> myRegularizations() {
        return regularizationRepository.findByOrgIdAndUserIdAndIsDeletedFalseOrderByWorkDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    @Transactional(readOnly = true)
    public List<AttendanceRegularization> pending() {
        return regularizationRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(
                TenantContext.getCurrentOrgId(), "PENDING");
    }

    // ── Monthly summary ──────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> monthlySummary(UUID userId, LocalDate month) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID uid = userId != null ? userId : TenantContext.getCurrentUserId();
        LocalDate from = month.withDayOfMonth(1);
        LocalDate to = from.plusMonths(1).minusDays(1);

        BigDecimal workingDays = leaveManagementService.workingDays(from, to);

        List<FieldAttendance> punches = attendanceRepository
                .findByOrgIdAndUserIdAndWorkDateBetweenOrderByWorkDateDesc(orgId, uid, from, to);
        int present = 0;
        double hours = 0;
        for (FieldAttendance a : punches) {
            if (a.getPunchInAt() != null) present++;
            if (a.getPunchInAt() != null && a.getPunchOutAt() != null) {
                hours += Duration.between(a.getPunchInAt(), a.getPunchOutAt()).toMinutes() / 60.0;
            }
        }

        BigDecimal leaveDays = BigDecimal.ZERO;
        for (LeaveRequest lr : leaveRequestRepository
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, uid, List.of("APPROVED"), to, from)) {
            LocalDate s = lr.getFromDate().isBefore(from) ? from : lr.getFromDate();
            LocalDate e = lr.getToDate().isAfter(to) ? to : lr.getToDate();
            leaveDays = leaveDays.add(leaveManagementService.workingDays(s, e));
        }

        int holidays = holidayRepository
                .findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(orgId, from, to).size();
        java.util.Set<DayOfWeek> weekend = countryAccessService.weekendDays();
        int weekends = 0;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            if (weekend.contains(d.getDayOfWeek())) weekends++;
        }

        BigDecimal absent = workingDays.subtract(BigDecimal.valueOf(present)).subtract(leaveDays)
                .max(BigDecimal.ZERO);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("userId", uid);
        out.put("month", from.toString());
        out.put("workingDays", workingDays);
        out.put("presentDays", present);
        out.put("leaveDays", leaveDays);
        out.put("holidays", holidays);
        out.put("weekends", weekends);
        out.put("absentDays", absent);
        out.put("totalHours", BigDecimal.valueOf(hours).setScale(1, RoundingMode.HALF_UP));
        // Payroll-relevant payable days = present + paid leave (LOP already nets unpaid out).
        out.put("payableDays", BigDecimal.valueOf(present).add(leaveDays));
        return out;
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private AttendanceRegularization loadPending(UUID id) {
        AttendanceRegularization reg = regularizationRepository
                .findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("AttendanceRegularization", id));
        if (!"PENDING".equals(reg.getStatus())) {
            throw new BusinessException(
                    "Regularization must be PENDING to decide (current: " + reg.getStatus() + ")",
                    "HR_REG_NOT_PENDING", org.springframework.http.HttpStatus.BAD_REQUEST);
        }
        return reg;
    }

    private static String appendNote(String existing, String note) {
        if (existing == null || existing.isBlank()) return note;
        return existing + " | " + note;
    }
}
