package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.TimesheetEntry;
import com.katasticho.erp.hr.repository.TimesheetEntryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * HR Timesheets — Core HR module 4. Per-day project/task time logs with a
 * DRAFT -> SUBMITTED -> APPROVED/REJECTED lifecycle, a billable flag, and
 * total / billable / by-project summaries.
 */
@Service
@RequiredArgsConstructor
public class TimesheetService {

    private static final BigDecimal MAX_HOURS = new BigDecimal("24");

    private final TimesheetEntryRepository repository;

    @Transactional
    public TimesheetEntry log(LocalDate workDate, String project, String task,
                              BigDecimal hours, boolean billable, String notes) {
        validateHours(hours);
        if (workDate == null) {
            throw new BusinessException("Work date is required", "HR_TS_NO_DATE", HttpStatus.BAD_REQUEST);
        }
        return repository.save(TimesheetEntry.builder()
                .orgId(TenantContext.getCurrentOrgId())
                .userId(TenantContext.getCurrentUserId())
                .workDate(workDate).project(project).task(task)
                .hours(hours).billable(billable).notes(notes)
                .status("DRAFT")
                .build());
    }

    @Transactional
    public TimesheetEntry update(UUID id, String project, String task,
                                 BigDecimal hours, boolean billable, String notes) {
        TimesheetEntry e = loadOwnedDraft(id);
        validateHours(hours);
        e.setProject(project);
        e.setTask(task);
        e.setHours(hours);
        e.setBillable(billable);
        e.setNotes(notes);
        return repository.save(e);
    }

    @Transactional
    public void delete(UUID id) {
        TimesheetEntry e = loadOwnedDraft(id);
        e.setDeleted(true);
        repository.save(e);
    }

    /** Submit all of the current user's DRAFT entries in a date range. */
    @Transactional
    public int submitRange(LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        List<TimesheetEntry> drafts = repository
                .findByOrgIdAndUserIdAndStatusAndWorkDateBetweenAndIsDeletedFalse(orgId, userId, "DRAFT", from, to);
        for (TimesheetEntry e : drafts) {
            e.setStatus("SUBMITTED");
        }
        repository.saveAll(drafts);
        return drafts.size();
    }

    @Transactional
    public TimesheetEntry approve(UUID id) {
        TimesheetEntry e = loadSubmitted(id);
        e.setStatus("APPROVED");
        e.setApprovedBy(TenantContext.getCurrentUserId());
        e.setDecidedAt(Instant.now());
        return repository.save(e);
    }

    @Transactional
    public TimesheetEntry reject(UUID id, String reason) {
        TimesheetEntry e = loadSubmitted(id);
        e.setStatus("REJECTED");
        e.setRejectionReason(reason);
        e.setDecidedAt(Instant.now());
        return repository.save(e);
    }

    @Transactional(readOnly = true)
    public List<TimesheetEntry> myEntries(LocalDate from, LocalDate to) {
        return repository.findByOrgIdAndUserIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(
                TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId(), from, to);
    }

    @Transactional(readOnly = true)
    public List<TimesheetEntry> pending() {
        return repository.findByOrgIdAndStatusAndIsDeletedFalseOrderByWorkDateDesc(
                TenantContext.getCurrentOrgId(), "SUBMITTED");
    }

    /** Total / billable hours and a by-project breakdown for a user in a range. */
    @Transactional(readOnly = true)
    public Map<String, Object> summary(UUID userId, LocalDate from, LocalDate to) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID uid = userId != null ? userId : TenantContext.getCurrentUserId();
        List<TimesheetEntry> entries = repository
                .findByOrgIdAndUserIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(orgId, uid, from, to);

        BigDecimal total = BigDecimal.ZERO, billable = BigDecimal.ZERO;
        Map<String, BigDecimal> byProject = new LinkedHashMap<>();
        for (TimesheetEntry e : entries) {
            BigDecimal h = e.getHours() != null ? e.getHours() : BigDecimal.ZERO;
            total = total.add(h);
            if (e.isBillable()) billable = billable.add(h);
            byProject.merge(e.getProject() != null ? e.getProject() : "(none)", h, BigDecimal::add);
        }
        List<Map<String, Object>> projects = new ArrayList<>();
        for (Map.Entry<String, BigDecimal> e : byProject.entrySet()) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("project", e.getKey());
            row.put("hours", e.getValue());
            projects.add(row);
        }
        projects.sort(Comparator.comparing(r -> ((BigDecimal) r.get("hours")).negate()));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("userId", uid);
        out.put("totalHours", total);
        out.put("billableHours", billable);
        out.put("nonBillableHours", total.subtract(billable));
        out.put("byProject", projects);
        return out;
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private void validateHours(BigDecimal hours) {
        if (hours == null || hours.signum() <= 0 || hours.compareTo(MAX_HOURS) > 0) {
            throw new BusinessException("Hours must be between 0 and 24", "HR_TS_BAD_HOURS", HttpStatus.BAD_REQUEST);
        }
    }

    private TimesheetEntry load(UUID id) {
        return repository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("TimesheetEntry", id));
    }

    private TimesheetEntry loadOwnedDraft(UUID id) {
        TimesheetEntry e = load(id);
        if (!e.getUserId().equals(TenantContext.getCurrentUserId())) {
            throw new BusinessException("Only the owner can edit this entry",
                    "HR_TS_NOT_OWNER", HttpStatus.FORBIDDEN);
        }
        if (!"DRAFT".equals(e.getStatus())) {
            throw new BusinessException("Only DRAFT entries can be edited (current: " + e.getStatus() + ")",
                    "HR_TS_NOT_DRAFT", HttpStatus.BAD_REQUEST);
        }
        return e;
    }

    private TimesheetEntry loadSubmitted(UUID id) {
        TimesheetEntry e = load(id);
        if (!"SUBMITTED".equals(e.getStatus())) {
            throw new BusinessException("Entry must be SUBMITTED to decide (current: " + e.getStatus() + ")",
                    "HR_TS_NOT_SUBMITTED", HttpStatus.BAD_REQUEST);
        }
        return e;
    }
}
