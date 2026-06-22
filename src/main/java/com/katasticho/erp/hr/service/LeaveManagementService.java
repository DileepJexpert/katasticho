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
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.*;

/**
 * HR Leave Management (Time off) — Core HR module 1. Configurable leave types,
 * an org holiday calendar, per-employee yearly balances, and balance-aware
 * apply / approve / cancel. Working days exclude weekends and holidays.
 *
 * Requests are persisted as {@link LeaveRequest} rows (leaveType = "UNPAID" for
 * unpaid types) so the payroll LOP path keeps working unchanged.
 */
@Service
@RequiredArgsConstructor
public class LeaveManagementService {

    private final LeaveTypeRepository leaveTypeRepository;
    private final HolidayRepository holidayRepository;
    private final LeaveBalanceRepository balanceRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final com.katasticho.erp.common.country.CountryAccessService countryAccessService;

    // ── Leave types ──────────────────────────────────────────────────────

    @Transactional
    public LeaveType upsertLeaveType(UUID id, String code, String name, boolean paid,
                                     BigDecimal annualQuota, String accrualMethod,
                                     BigDecimal carryForwardMax, boolean requiresApproval,
                                     boolean active) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (code == null || code.isBlank() || name == null || name.isBlank()) {
            throw new BusinessException("Leave type code and name are required",
                    "HR_LEAVE_TYPE_INVALID", HttpStatus.BAD_REQUEST);
        }
        LeaveType type = id != null
                ? leaveTypeRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                    .orElseThrow(() -> BusinessException.notFound("LeaveType", id))
                : LeaveType.builder().orgId(orgId).createdBy(TenantContext.getCurrentUserId()).build();
        if (id == null) {
            leaveTypeRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code.trim().toUpperCase())
                    .ifPresent(x -> { throw new BusinessException("Leave type code already exists",
                            "HR_LEAVE_TYPE_DUPLICATE", HttpStatus.CONFLICT); });
        }
        type.setCode(code.trim().toUpperCase());
        type.setName(name.trim());
        type.setPaid(paid);
        type.setAnnualQuota(nz(annualQuota));
        type.setAccrualMethod(normaliseAccrual(accrualMethod));
        type.setCarryForwardMax(nz(carryForwardMax));
        type.setRequiresApproval(requiresApproval);
        type.setActive(active);
        return leaveTypeRepository.save(type);
    }

    @Transactional(readOnly = true)
    public List<LeaveType> listLeaveTypes(boolean activeOnly) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return activeOnly
                ? leaveTypeRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByNameAsc(orgId)
                : leaveTypeRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId);
    }

    // ── Holidays ─────────────────────────────────────────────────────────

    @Transactional
    public Holiday addHoliday(LocalDate date, String name, boolean optional) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (holidayRepository.existsByOrgIdAndHolidayDateAndIsDeletedFalse(orgId, date)) {
            throw new BusinessException("A holiday already exists on " + date,
                    "HR_HOLIDAY_DUPLICATE", HttpStatus.CONFLICT);
        }
        return holidayRepository.save(Holiday.builder()
                .orgId(orgId).holidayDate(date).name(name).optional(optional).build());
    }

    @Transactional
    public void deleteHoliday(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Holiday h = holidayRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Holiday", id));
        h.setDeleted(true);
        holidayRepository.save(h);
    }

    @Transactional(readOnly = true)
    public List<Holiday> listHolidays(int year) {
        return holidayRepository.findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(
                TenantContext.getCurrentOrgId(), LocalDate.of(year, 1, 1), LocalDate.of(year, 12, 31));
    }

    // ── Apply / decide ───────────────────────────────────────────────────

    @Transactional
    public LeaveRequest applyLeave(UUID leaveTypeId, LocalDate from, LocalDate to, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (from == null || to == null || to.isBefore(from)) {
            throw new BusinessException("Invalid leave date range", "HR_LEAVE_BAD_RANGE", HttpStatus.BAD_REQUEST);
        }
        LeaveType type = loadType(leaveTypeId);

        BigDecimal days = workingDays(from, to);
        if (days.signum() <= 0) {
            throw new BusinessException("The selected dates have no working days (weekend/holiday only)",
                    "HR_LEAVE_NO_WORKING_DAYS", HttpStatus.BAD_REQUEST);
        }

        boolean overlaps = !leaveRequestRepository
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, userId, List.of("PENDING", "APPROVED"), to, from)
                .isEmpty();
        if (overlaps) {
            throw new BusinessException("This overlaps an existing leave request",
                    "LEAVE_OVERLAPS", HttpStatus.CONFLICT);
        }

        LeaveBalance balance = null;
        if (type.isPaid()) {
            balance = getOrCreateBalance(userId, type, from.getYear());
            if (balance.getAvailable().compareTo(days) < 0) {
                throw new BusinessException(
                        "Insufficient " + type.getName() + " balance (available "
                                + balance.getAvailable().toPlainString() + ", requested " + days.toPlainString() + ")",
                        "HR_LEAVE_INSUFFICIENT_BALANCE", HttpStatus.BAD_REQUEST);
            }
        }

        boolean autoApprove = !type.isRequiresApproval();
        LeaveRequest req = LeaveRequest.builder()
                .orgId(orgId).userId(userId)
                .fromDate(from).toDate(to)
                .leaveType(type.isPaid() ? type.getCode() : "UNPAID")
                .leaveTypeId(type.getId())
                .workingDays(days)
                .reason(reason)
                .status(autoApprove ? "APPROVED" : "PENDING")
                .build();
        if (autoApprove && balance != null) {
            balance.setUsed(balance.getUsed().add(days));
            balanceRepository.save(balance);
        }
        return leaveRequestRepository.save(req);
    }

    @Transactional
    public LeaveRequest approveLeave(UUID leaveId) {
        LeaveRequest req = loadPending(leaveId);
        req.setStatus("APPROVED");
        req.setApprovedBy(TenantContext.getCurrentUserId());
        adjustBalanceOnDecision(req, true);
        return leaveRequestRepository.save(req);
    }

    @Transactional
    public LeaveRequest rejectLeave(UUID leaveId, String reason) {
        LeaveRequest req = loadPending(leaveId);
        req.setStatus("REJECTED");
        req.setRejectionReason(reason);
        return leaveRequestRepository.save(req);
    }

    @Transactional
    public LeaveRequest cancelLeave(UUID leaveId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        LeaveRequest req = leaveRequestRepository.findByIdAndOrgIdAndIsDeletedFalse(leaveId, orgId)
                .orElseThrow(() -> BusinessException.notFound("LeaveRequest", leaveId));
        if ("CANCELLED".equals(req.getStatus()) || "REJECTED".equals(req.getStatus())) {
            return req;
        }
        boolean wasApproved = "APPROVED".equals(req.getStatus());
        req.setStatus("CANCELLED");
        if (wasApproved) adjustBalanceOnDecision(req, false);   // restore
        return leaveRequestRepository.save(req);
    }

    @Transactional
    public List<Map<String, Object>> myBalances(int year) {
        UUID userId = TenantContext.getCurrentUserId();
        List<Map<String, Object>> rows = new ArrayList<>();
        for (LeaveType type : listLeaveTypes(true)) {
            if (!type.isPaid()) continue;   // unpaid types have no balance
            LeaveBalance b = getOrCreateBalance(userId, type, year);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("leaveTypeId", type.getId());
            row.put("leaveType", type.getName());
            row.put("entitled", b.getEntitled());
            row.put("carriedForward", b.getCarriedForward());
            row.put("used", b.getUsed());
            row.put("available", b.getAvailable());
            rows.add(row);
        }
        return rows;
    }

    @Transactional(readOnly = true)
    public List<LeaveRequest> myLeaves() {
        return leaveRequestRepository.findByOrgIdAndUserIdAndIsDeletedFalseOrderByFromDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
    }

    @Transactional(readOnly = true)
    public List<LeaveRequest> pendingLeaves() {
        return leaveRequestRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByFromDateDesc(
                TenantContext.getCurrentOrgId(), "PENDING");
    }

    // ── helpers ──────────────────────────────────────────────────────────

    /** Working days in [from, to] inclusive, excluding weekends and holidays. */
    BigDecimal workingDays(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Set<LocalDate> holidays = new HashSet<>();
        for (Holiday h : holidayRepository
                .findByOrgIdAndHolidayDateBetweenAndIsDeletedFalseOrderByHolidayDateAsc(orgId, from, to)) {
            holidays.add(h.getHolidayDate());
        }
        Set<DayOfWeek> weekend = countryAccessService.weekendDays();
        int count = 0;
        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            if (weekend.contains(d.getDayOfWeek())) continue;
            if (holidays.contains(d)) continue;
            count++;
        }
        return BigDecimal.valueOf(count);
    }

    LeaveBalance getOrCreateBalance(UUID userId, LeaveType type, int year) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return balanceRepository
                .findByOrgIdAndUserIdAndLeaveTypeIdAndYearAndIsDeletedFalse(orgId, userId, type.getId(), year)
                .orElseGet(() -> balanceRepository.save(LeaveBalance.builder()
                        .orgId(orgId).userId(userId).leaveTypeId(type.getId()).year(year)
                        .entitled(entitledFor(type, year))
                        .build()));
    }

    /** Entitlement at creation: full quota, or accrued-to-date for MONTHLY in the current year. */
    private BigDecimal entitledFor(LeaveType type, int year) {
        if ("MONTHLY".equals(type.getAccrualMethod()) && year == LocalDate.now().getYear()) {
            int month = LocalDate.now().getMonthValue();
            return type.getAnnualQuota().multiply(BigDecimal.valueOf(month))
                    .divide(BigDecimal.valueOf(12), 1, RoundingMode.HALF_UP);
        }
        return "NONE".equals(type.getAccrualMethod()) ? type.getAnnualQuota() : type.getAnnualQuota();
    }

    private void adjustBalanceOnDecision(LeaveRequest req, boolean consume) {
        if (req.getLeaveTypeId() == null || req.getWorkingDays() == null) return;
        LeaveType type = leaveTypeRepository
                .findByIdAndOrgIdAndIsDeletedFalse(req.getLeaveTypeId(), req.getOrgId()).orElse(null);
        if (type == null || !type.isPaid()) return;
        LeaveBalance b = getOrCreateBalance(req.getUserId(), type, req.getFromDate().getYear());
        b.setUsed(consume ? b.getUsed().add(req.getWorkingDays())
                          : b.getUsed().subtract(req.getWorkingDays()).max(BigDecimal.ZERO));
        balanceRepository.save(b);
    }

    private LeaveType loadType(UUID id) {
        LeaveType type = leaveTypeRepository
                .findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("LeaveType", id));
        if (!type.isActive()) {
            throw new BusinessException("Leave type is inactive", "HR_LEAVE_TYPE_INACTIVE", HttpStatus.BAD_REQUEST);
        }
        return type;
    }

    private LeaveRequest loadPending(UUID leaveId) {
        LeaveRequest req = leaveRequestRepository
                .findByIdAndOrgIdAndIsDeletedFalse(leaveId, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("LeaveRequest", leaveId));
        if (!"PENDING".equals(req.getStatus())) {
            throw new BusinessException("Leave must be PENDING to decide (current: " + req.getStatus() + ")",
                    "HR_LEAVE_NOT_PENDING", HttpStatus.BAD_REQUEST);
        }
        return req;
    }

    private static String normaliseAccrual(String m) {
        String v = m != null ? m.toUpperCase(Locale.ROOT) : "ANNUAL";
        return Set.of("ANNUAL", "MONTHLY", "NONE").contains(v) ? v : "ANNUAL";
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
