package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.Offboarding;
import com.katasticho.erp.hr.entity.OffboardingTask;
import com.katasticho.erp.hr.repository.OffboardingRepository;
import com.katasticho.erp.hr.repository.OffboardingTaskRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * HR Offboarding — Core HR module 9. Exit/resignation flow: initiate (seeds a
 * clearance checklist) -> complete the IT/Finance/HR/Admin tasks -> settle
 * full-and-final -> complete (marks the payroll Employee EXITED).
 */
@Service
@RequiredArgsConstructor
public class OffboardingService {

    /** Default clearance checklist seeded on initiation. */
    private static final List<String[]> DEFAULT_TASKS = List.of(
            new String[]{"IT", "Return laptop and IT assets"},
            new String[]{"IT", "Revoke system access / accounts"},
            new String[]{"FINANCE", "Clear advances and dues"},
            new String[]{"HR", "Conduct exit interview"},
            new String[]{"ADMIN", "Return ID card and access cards"});

    private final OffboardingRepository offboardingRepository;
    private final OffboardingTaskRepository taskRepository;
    private final EmployeeRepository employeeRepository;

    @Transactional
    public Map<String, Object> initiate(UUID employeeUserId, LocalDate resignationDate,
                                        LocalDate lastWorkingDay, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Offboarding ob = offboardingRepository.save(Offboarding.builder()
                .orgId(orgId).employeeUserId(employeeUserId)
                .initiatedBy(TenantContext.getCurrentUserId())
                .resignationDate(resignationDate).lastWorkingDay(lastWorkingDay)
                .reason(reason).status("INITIATED")
                .build());
        for (String[] t : DEFAULT_TASKS) {
            taskRepository.save(OffboardingTask.builder()
                    .orgId(orgId).offboardingId(ob.getId())
                    .category(t[0]).label(t[1])
                    .build());
        }
        return view(ob);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getOffboarding(UUID id) {
        return view(load(id));
    }

    @Transactional
    public OffboardingTask completeTask(UUID taskId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        OffboardingTask task = taskRepository.findById(taskId)
                .filter(t -> orgId.equals(t.getOrgId()) && !t.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("OffboardingTask", taskId));
        task.setCompleted(true);
        task.setCompletedBy(TenantContext.getCurrentUserId());
        task.setCompletedAt(Instant.now());
        return taskRepository.save(task);
    }

    @Transactional
    public Offboarding settleFnf(UUID id, BigDecimal amount) {
        Offboarding ob = load(id);
        ob.setFnfAmount(amount);
        ob.setFnfSettled(true);
        return offboardingRepository.save(ob);
    }

    /** Finish offboarding: all clearance tasks must be done; marks the employee EXITED. */
    @Transactional
    public Offboarding complete(UUID id) {
        Offboarding ob = load(id);
        if (!"INITIATED".equals(ob.getStatus())) {
            throw new BusinessException("Offboarding is not in progress (status: " + ob.getStatus() + ")",
                    "OFFB_NOT_OPEN", HttpStatus.BAD_REQUEST);
        }
        List<OffboardingTask> tasks = taskRepository
                .findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(ob.getOrgId(), ob.getId());
        if (tasks.stream().anyMatch(t -> !t.isCompleted())) {
            throw new BusinessException("All clearance tasks must be completed first",
                    "OFFB_TASKS_PENDING", HttpStatus.BAD_REQUEST);
        }
        ob.setStatus("COMPLETED");
        offboardingRepository.save(ob);

        // Mark the linked payroll employee as exited, if one exists.
        employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(ob.getOrgId(), ob.getEmployeeUserId())
                .ifPresent(emp -> {
                    emp.setEmploymentStatus("EXITED");
                    if (ob.getLastWorkingDay() != null) emp.setDateOfExit(ob.getLastWorkingDay());
                    employeeRepository.save(emp);
                });
        return ob;
    }

    @Transactional
    public Offboarding cancel(UUID id) {
        Offboarding ob = load(id);
        ob.setStatus("CANCELLED");
        return offboardingRepository.save(ob);
    }

    @Transactional(readOnly = true)
    public List<Offboarding> list(String status) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return (status == null || status.isBlank())
                ? offboardingRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId)
                : offboardingRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(
                        orgId, status.trim().toUpperCase());
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private Offboarding load(UUID id) {
        return offboardingRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Offboarding", id));
    }

    private Map<String, Object> view(Offboarding ob) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("offboarding", ob);
        out.put("tasks", taskRepository
                .findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(ob.getOrgId(), ob.getId()));
        return out;
    }
}
