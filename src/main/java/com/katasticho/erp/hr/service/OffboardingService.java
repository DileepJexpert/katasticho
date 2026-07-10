package com.katasticho.erp.hr.service;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.Offboarding;
import com.katasticho.erp.hr.entity.OffboardingTask;
import com.katasticho.erp.hr.repository.OffboardingRepository;
import com.katasticho.erp.hr.repository.OffboardingTaskRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.gulf.GratuityResult;
import com.katasticho.erp.payroll.gulf.GulfPayrollService;
import com.katasticho.erp.payroll.india.IndiaGratuityResult;
import com.katasticho.erp.payroll.india.IndiaGratuityService;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
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

    /** Gulf gratuity GL codes (V15 seed: 2050 Gratuity Provision, 5060 Gratuity Expense). */
    private static final String GRATUITY_PROVISION_CODE = "2050";
    /** India gratuity provision GL (V25 seed: 2080; 2050 is PF Payable in the IN chart). */
    private static final String INDIA_GRATUITY_PROVISION_CODE = "2080";
    /** Default payout cash account when org doesn't override via setting. */
    private static final String DEFAULT_PAYMENT_ACCOUNT_CODE = "1010";
    private static final String GRATUITY_PAYMENT_ACCOUNT_SETTING = "payroll.gratuity_payment_account_code";

    private final OffboardingRepository offboardingRepository;
    private final OffboardingTaskRepository taskRepository;
    private final EmployeeRepository employeeRepository;
    private final CountryAccessService countryAccessService;
    private final GulfPayrollService gulfPayrollService;
    private final IndiaGratuityService indiaGratuityService;
    private final JournalService journalService;
    private final AccountRepository accountRepository;
    private final OrgSettingsService orgSettingsService;
    private final Clock clock;

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

    /**
     * Post the Gulf end-of-service gratuity payout for a terminating employee.
     *
     * <p>UAE Decree-Law 33/2021 + Oman Royal Decree 35/2003. Computes the
     * lump-sum entitlement from the employee's joining date and current
     * monthly basic, then posts:
     * <pre>
     *   DR Gratuity Provision (2050) — payout
     *   CR Cash / Bank — payout
     * </pre>
     * Any drift between the cumulative monthly accrual (V15) and the
     * computed lump sum is the org's financial-reporting concern; the
     * payroll/HR path doesn't try to true it up here.
     *
     * <p>Idempotent: a second call when {@code gratuityJournalEntryId} is
     * already set throws {@code OFFB_GRATUITY_ALREADY_PAID}. Country-gated
     * to AE/OM — Indian orgs use the separate Payment-of-Gratuity-Act 1972
     * flow (not modelled yet). Service-less-than-1-year returns an
     * {@code OFFB_GRATUITY_NIL} stamp with no journal entry — the labour-law
     * forfeiture rule.
     *
     * @param id offboarding id
     * @param paymentAccountCode optional override; default = org setting
     *     {@code payroll.gratuity_payment_account_code}, else {@code 1010}
     *     (Cash). Caller can pass a bank code (e.g. {@code 1020}).
     */
    @Transactional
    public Offboarding payGratuity(UUID id, String paymentAccountCode) {
        Offboarding ob = load(id);
        UUID orgId = ob.getOrgId();

        String country = countryAccessService.countryOf(orgId);
        boolean gulf = "AE".equals(country) || "OM".equals(country);
        boolean india = "IN".equals(country);
        if (!gulf && !india) {
            throw new BusinessException(
                    "Gratuity payout is modelled for UAE / Oman (end-of-service) and "
                            + "India (Payment of Gratuity Act) only (got " + country + ")",
                    "OFFB_GRATUITY_NOT_APPLICABLE", HttpStatus.BAD_REQUEST);
        }
        if (ob.getGratuityJournalEntryId() != null) {
            throw new BusinessException(
                    "Gratuity already paid (journal " + ob.getGratuityJournalEntryId() + ")",
                    "OFFB_GRATUITY_ALREADY_PAID", HttpStatus.CONFLICT);
        }

        Employee emp = employeeRepository
                .findByOrgIdAndUserIdAndIsDeletedFalse(orgId, ob.getEmployeeUserId())
                .orElseThrow(() -> new BusinessException(
                        "No payroll Employee linked to this offboarding's user",
                        "OFFB_GRATUITY_NO_EMPLOYEE", HttpStatus.BAD_REQUEST));

        LocalDate asOf = ob.getLastWorkingDay() != null
                ? ob.getLastWorkingDay()
                : LocalDate.now(clock);

        // Country-aware formula: Gulf 21/30-day tiers vs India 15/26 × years.
        // Both computeFor resolve the structure's wage and throw
        // GRATUITY_NO_BASIC / GRATUITY_NO_STRUCTURE on misconfig. India's
        // cappedAmount is ZERO until 5 continuous years (§4 eligibility).
        BigDecimal payout;
        String provisionCode;
        if (gulf) {
            GratuityResult result = gulfPayrollService.computeFor(emp.getId(), asOf);
            payout = result.cappedGratuity();
            provisionCode = GRATUITY_PROVISION_CODE;
        } else {
            IndiaGratuityResult result = indiaGratuityService.computeFor(emp.getId(), asOf);
            payout = result.cappedAmount();
            provisionCode = INDIA_GRATUITY_PROVISION_CODE;
        }

        Instant now = Instant.now(clock);
        if (payout == null || payout.signum() <= 0) {
            // Forfeit / not-yet-eligible case — flag the offboarding so HR sees
            // "computed but nothing to pay" without a phantom 0-rupee journal.
            ob.setGratuityAmount(BigDecimal.ZERO);
            ob.setGratuityPaidAt(now);
            return offboardingRepository.save(ob);
        }

        String payCode = resolvePaymentAccountCode(orgId, paymentAccountCode);
        ensureAccount(orgId, provisionCode, "Gratuity Provision");
        ensureAccount(orgId, payCode, "payout account " + payCode);

        List<JournalLineRequest> lines = List.of(
                new JournalLineRequest(provisionCode, payout, BigDecimal.ZERO,
                        "End-of-service gratuity payout", null, null),
                new JournalLineRequest(payCode, BigDecimal.ZERO, payout,
                        "End-of-service gratuity payout", null, null));

        String desc = "Gratuity payout — exit of employee " + emp.getEmployeeCode();
        JournalEntry entry = journalService.postJournal(new JournalPostRequest(
                asOf, desc, "HR_OFFBOARDING", ob.getId(), lines, true));

        ob.setGratuityAmount(payout);
        ob.setGratuityJournalEntryId(entry.getId());
        ob.setGratuityPaidAt(now);
        return offboardingRepository.save(ob);
    }

    private String resolvePaymentAccountCode(UUID orgId, String override) {
        if (override != null && !override.isBlank()) return override.trim();
        String setting = orgSettingsService.get(orgId, GRATUITY_PAYMENT_ACCOUNT_SETTING, "");
        return (setting == null || setting.isBlank())
                ? DEFAULT_PAYMENT_ACCOUNT_CODE
                : setting.trim();
    }

    private void ensureAccount(UUID orgId, String code, String label) {
        Account a = accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                .orElseThrow(() -> new BusinessException(
                        "Missing CoA account " + code + " (" + label + ")",
                        "OFFB_GRATUITY_ACCOUNT_MISSING_" + code,
                        HttpStatus.PRECONDITION_FAILED));
        // findByOrgIdAndCodeAndIsDeletedFalse already filters by org; presence check is enough.
        if (a == null) throw new IllegalStateException("unreachable");
    }

    @Transactional
    public Offboarding cancel(UUID id) {
        Offboarding ob = load(id);
        // Only an in-progress offboarding may be cancelled. A COMPLETED exit has
        // already flipped the payroll employee to EXITED; cancelling it would
        // wrongly imply a rollback that never happens (the employee stays EXITED),
        // and a CANCELLED one is a no-op.
        if (!"INITIATED".equals(ob.getStatus())) {
            throw new BusinessException(
                    "Cannot cancel offboarding in status " + ob.getStatus(),
                    "OFFB_FINAL_STATE", HttpStatus.BAD_REQUEST);
        }
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
