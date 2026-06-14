package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.Shift;
import com.katasticho.erp.hr.entity.ShiftAssignment;
import com.katasticho.erp.hr.repository.ShiftAssignmentRepository;
import com.katasticho.erp.hr.repository.ShiftRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * HR Shift management — Core HR module 3. Shift definitions and per-employee
 * shift assignments over date ranges. Assigning a new shift auto-closes the
 * employee's current open-ended assignment so timelines never overlap.
 */
@Service
@RequiredArgsConstructor
public class ShiftManagementService {

    private final ShiftRepository shiftRepository;
    private final ShiftAssignmentRepository assignmentRepository;

    // ── Shift definitions ────────────────────────────────────────────────

    @Transactional
    public Shift upsertShift(UUID id, String code, String name, LocalTime start, LocalTime end,
                             String weeklyOffs, boolean active) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (code == null || code.isBlank() || name == null || name.isBlank()
                || start == null || end == null) {
            throw new BusinessException("Shift code, name, start and end time are required",
                    "HR_SHIFT_INVALID", HttpStatus.BAD_REQUEST);
        }
        Shift shift = id != null
                ? shiftRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                    .orElseThrow(() -> BusinessException.notFound("Shift", id))
                : Shift.builder().orgId(orgId).createdBy(TenantContext.getCurrentUserId()).build();
        if (id == null) {
            shiftRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code.trim().toUpperCase())
                    .ifPresent(x -> { throw new BusinessException("Shift code already exists",
                            "HR_SHIFT_DUPLICATE", HttpStatus.CONFLICT); });
        }
        shift.setCode(code.trim().toUpperCase());
        shift.setName(name.trim());
        shift.setStartTime(start);
        shift.setEndTime(end);
        shift.setWeeklyOffs(weeklyOffs != null ? weeklyOffs.toUpperCase() : "SAT,SUN");
        shift.setActive(active);
        return shiftRepository.save(shift);
    }

    @Transactional(readOnly = true)
    public List<Shift> listShifts(boolean activeOnly) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return activeOnly
                ? shiftRepository.findByOrgIdAndActiveTrueAndIsDeletedFalseOrderByNameAsc(orgId)
                : shiftRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId);
    }

    // ── Assignments ──────────────────────────────────────────────────────

    @Transactional
    public ShiftAssignment assignShift(UUID userId, UUID shiftId, LocalDate effectiveFrom, LocalDate effectiveTo) {
        UUID orgId = TenantContext.getCurrentOrgId();
        shiftRepository.findByIdAndOrgIdAndIsDeletedFalse(shiftId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Shift", shiftId));
        if (effectiveFrom == null) {
            throw new BusinessException("effectiveFrom is required", "HR_SHIFT_ASSIGN_INVALID", HttpStatus.BAD_REQUEST);
        }
        if (effectiveTo != null && effectiveTo.isBefore(effectiveFrom)) {
            throw new BusinessException("effectiveTo cannot be before effectiveFrom",
                    "HR_SHIFT_ASSIGN_BAD_RANGE", HttpStatus.BAD_REQUEST);
        }

        // Close any open-ended current assignment the day before the new one starts.
        for (ShiftAssignment open : assignmentRepository
                .findByOrgIdAndUserIdAndEffectiveToIsNullAndIsDeletedFalse(orgId, userId)) {
            if (!open.getEffectiveFrom().isAfter(effectiveFrom)) {
                open.setEffectiveTo(effectiveFrom.minusDays(1));
                assignmentRepository.save(open);
            }
        }

        return assignmentRepository.save(ShiftAssignment.builder()
                .orgId(orgId).userId(userId).shiftId(shiftId)
                .effectiveFrom(effectiveFrom).effectiveTo(effectiveTo)
                .createdBy(TenantContext.getCurrentUserId())
                .build());
    }

    @Transactional(readOnly = true)
    public List<ShiftAssignment> listAssignments(UUID userId) {
        return assignmentRepository.findByOrgIdAndUserIdAndIsDeletedFalseOrderByEffectiveFromDesc(
                TenantContext.getCurrentOrgId(), userId);
    }

    /** The shift effective for a user on a date (the latest assignment covering it). */
    @Transactional(readOnly = true)
    public Optional<Shift> shiftOn(UUID userId, LocalDate date) {
        UUID orgId = TenantContext.getCurrentOrgId();
        for (ShiftAssignment a : assignmentRepository
                .findByOrgIdAndUserIdAndEffectiveFromLessThanEqualAndIsDeletedFalseOrderByEffectiveFromDesc(
                        orgId, userId, date)) {
            if (a.getEffectiveTo() == null || !a.getEffectiveTo().isBefore(date)) {
                return shiftRepository.findByIdAndOrgIdAndIsDeletedFalse(a.getShiftId(), orgId);
            }
        }
        return Optional.empty();
    }
}
