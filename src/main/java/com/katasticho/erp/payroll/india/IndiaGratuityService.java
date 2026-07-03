package com.katasticho.erp.payroll.india;

import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeSalaryStructure;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.EmployeeSalaryStructureRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * India gratuity under the Payment of Gratuity Act 1972 — the Indian parallel
 * to the Gulf end-of-service gratuity ({@code GulfPayrollService}).
 *
 * <h2>Formula</h2>
 * <pre>
 *   gratuity = (last-drawn basic + DA) × 15/26 × completed years of service
 * </pre>
 * <ul>
 *   <li>Eligibility: 5 continuous years of service (§4).</li>
 *   <li>Completed years use §4(2) rounding — a final year of ≥ 6 months rounds
 *       up to a full year.</li>
 *   <li>15/26 = 15 days' wages per year, treating a month as 26 working days.</li>
 *   <li>Statutory ceiling ₹20,00,000 — applied at payout only, not the accrual.</li>
 * </ul>
 *
 * <h2>Accrual (AS 15 / Ind AS 19)</h2>
 * The lump sum is paid only at exit, but the liability is provisioned monthly
 * so the P&amp;L matches the period earned. Monthly slice = annual gratuity
 * (basic+DA × 15/26) ÷ 12. {@link #postAccrual} posts ONE consolidated journal
 * per period — DR 5130 Gratuity Expense / CR 2080 Gratuity Provision — rather
 * than a per-payslip line, because India gratuity is a provision, not a
 * payslip statutory like PF/ESI. Idempotent per (org, period).
 *
 * <p>Gated on the org setting {@code payroll.india_gratuity_enabled} (default
 * off) — an India org opts in, exactly like the PF/ESI/PT/LWF toggles.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class IndiaGratuityService {

    /** §4(3) statutory ceiling since 29 Mar 2018. Applied at payout only. */
    static final BigDecimal STATUTORY_CEILING = new BigDecimal("2000000");
    private static final BigDecimal FIFTEEN = new BigDecimal("15");
    private static final BigDecimal TWENTY_SIX = new BigDecimal("26");
    private static final BigDecimal TWELVE = new BigDecimal("12");
    private static final int ELIGIBILITY_MONTHS = 60; // 5 continuous years

    static final String ENABLED_SETTING = "payroll.india_gratuity_enabled";
    static final String PROVISION_CODE = "2080";
    static final String EXPENSE_CODE = "5130";

    private final EmployeeRepository employeeRepository;
    private final EmployeeSalaryStructureRepository salaryStructureRepository;
    private final AccountRepository accountRepository;
    private final JournalService journalService;
    private final OrgSettingsService orgSettingsService;
    private final IndiaGratuityAccrualRepository accrualRepository;
    private final Clock clock;

    // ── Computation (pure math, no DB) ──────────────────────────────────────

    /**
     * The payout figure at {@code to}: eligible only after 5 continuous years,
     * amount = (basic+DA) × 15/26 × §4(2)-rounded completed years, ceiling
     * ₹20L. When not yet eligible the amount is ZERO (nothing payable) but the
     * years are still reported so HR sees how close the employee is.
     */
    public IndiaGratuityResult compute(LocalDate from, LocalDate to, BigDecimal monthlyBasicPlusDa) {
        if (from == null || to == null || !to.isAfter(from)) {
            throw new BusinessException("Service end date must be after start date",
                    "GRATUITY_INVALID_RANGE", HttpStatus.BAD_REQUEST);
        }
        if (monthlyBasicPlusDa == null || monthlyBasicPlusDa.signum() <= 0) {
            throw new BusinessException("Monthly basic + DA must be positive",
                    "GRATUITY_NO_BASIC", HttpStatus.BAD_REQUEST);
        }

        long fullMonths = ChronoUnit.MONTHS.between(from, to);
        int fullYears = (int) (fullMonths / 12);
        int leftoverMonths = (int) (fullMonths % 12);
        // §4(2): a fraction of a year of six months or more counts as a full year.
        int completedYears = fullYears + (leftoverMonths >= 6 ? 1 : 0);
        BigDecimal yearsExact = BigDecimal.valueOf(fullMonths)
                .divide(TWELVE, 3, RoundingMode.HALF_UP);
        boolean eligible = fullMonths >= ELIGIBILITY_MONTHS;

        BigDecimal gratuity = eligible
                ? monthlyBasicPlusDa.multiply(FIFTEEN).multiply(BigDecimal.valueOf(completedYears))
                        .divide(TWENTY_SIX, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        BigDecimal capped = gratuity.min(STATUTORY_CEILING);

        String formula = eligible
                ? "India: (basic+DA) × 15/26 × " + completedYears
                        + " completed years; capped at ₹20,00,000"
                : "Not eligible — under 5 continuous years (" + yearsExact + " years)";

        return new IndiaGratuityResult(yearsExact, completedYears, eligible,
                monthlyBasicPlusDa, gratuity, capped, formula);
    }

    /**
     * Monthly provision slice = (basic+DA) × 15/26 ÷ 12, accrued from the day
     * of joining per AS 15 / Ind AS 19. Returns ZERO on missing/invalid inputs.
     *
     * <p>Accrual is deliberately from joining (not deferred to the 5-year
     * vesting cliff): building the provision evenly means the cumulative 2080
     * balance matches the computed gratuity at exit, so the payout draws the
     * provision cleanly to zero. A "defer until vested" mode was removed — it
     * under-provisioned every month before the cliff and could not be trued up
     * to the vested liability without per-employee cumulative tracking, which
     * drove 2080 to a debit (negative liability) balance at payout.
     */
    public BigDecimal monthlyAccrual(LocalDate joinDate, LocalDate asOf,
                                     BigDecimal monthlyBasicPlusDa) {
        if (joinDate == null || asOf == null || monthlyBasicPlusDa == null
                || monthlyBasicPlusDa.signum() <= 0 || !asOf.isAfter(joinDate)) {
            return BigDecimal.ZERO;
        }
        return monthlyBasicPlusDa.multiply(FIFTEEN)
                .divide(TWENTY_SIX.multiply(TWELVE), 2, RoundingMode.HALF_UP);
    }

    @Transactional(readOnly = true)
    public IndiaGratuityResult computeFor(UUID employeeId, LocalDate asOf) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Employee employee = employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", employeeId));
        if (employee.getDateOfJoining() == null) {
            throw new BusinessException(
                    "Employee has no date of joining — gratuity needs a service start date",
                    "GRATUITY_NO_JOIN_DATE", HttpStatus.BAD_REQUEST);
        }
        LocalDate endDate = asOf != null ? asOf
                : (employee.getDateOfExit() != null ? employee.getDateOfExit() : LocalDate.now(clock));
        BigDecimal basicPlusDa = resolveMonthlyBasicPlusDa(employeeId, endDate);
        return compute(employee.getDateOfJoining(), endDate, basicPlusDa);
    }

    // ── Monthly accrual (preview + post) ────────────────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> previewAccrual(int year, int month) {
        return buildAccrual(year, month);
    }

    @Transactional
    public Map<String, Object> postAccrual(int year, int month) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (!Boolean.parseBoolean(orgSettingsService.get(orgId, ENABLED_SETTING, "false"))) {
            throw new BusinessException(
                    "India gratuity is disabled — enable it in payroll settings first.",
                    "GRATUITY_DISABLED", HttpStatus.BAD_REQUEST);
        }
        accrualRepository.findByOrgIdAndPeriodYearAndPeriodMonthAndIsDeletedFalse(orgId, year, month)
                .ifPresent(existing -> {
                    throw new BusinessException(
                            "Gratuity already accrued for " + year + "-" + month
                                    + " (journal " + existing.getJournalEntryId() + ")",
                            "GRATUITY_ALREADY_ACCRUED", HttpStatus.CONFLICT);
                });

        Map<String, Object> accrual = buildAccrual(year, month);
        BigDecimal total = (BigDecimal) accrual.get("totalAmount");
        int employeeCount = (int) accrual.get("employeeCount");
        if (total.signum() <= 0) {
            throw new BusinessException(
                    "Nothing to accrue for " + year + "-" + month
                            + " — no active employees with a positive basic + DA.",
                    "GRATUITY_NOTHING_TO_ACCRUE", HttpStatus.BAD_REQUEST);
        }

        ensureIndiaGratuityAccount(orgId, EXPENSE_CODE, "Gratuity Expense");
        ensureIndiaGratuityAccount(orgId, PROVISION_CODE, "Gratuity Provision");
        LocalDate periodEnd = LocalDate.of(year, month, 1)
                .plusMonths(1).minusDays(1);
        List<JournalLineRequest> lines = List.of(
                new JournalLineRequest(EXPENSE_CODE, total, BigDecimal.ZERO,
                        "Gratuity provision — " + year + "-" + month, null, null),
                new JournalLineRequest(PROVISION_CODE, BigDecimal.ZERO, total,
                        "Gratuity provision — " + year + "-" + month, null, null));
        JournalEntry entry = journalService.postJournal(new JournalPostRequest(
                periodEnd, "India gratuity accrual " + year + "-" + month,
                "PAYROLL", null, lines, true));

        IndiaGratuityAccrual row = IndiaGratuityAccrual.builder()
                .periodYear(year).periodMonth(month)
                .totalAmount(total).employeeCount(employeeCount)
                .journalEntryId(entry.getId())
                .build();
        row.setOrgId(orgId);
        row.setCreatedBy(TenantContext.getCurrentUserId());
        accrualRepository.save(row);

        accrual.put("journalEntryId", entry.getId());
        accrual.put("posted", true);
        return accrual;
    }

    private Map<String, Object> buildAccrual(int year, int month) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (month < 1 || month > 12) {
            throw new BusinessException("Month must be 1-12", "GRATUITY_BAD_MONTH", HttpStatus.BAD_REQUEST);
        }
        LocalDate periodStart = LocalDate.of(year, month, 1);
        LocalDate periodEnd = periodStart.plusMonths(1).minusDays(1);

        // Employees employed DURING the period, not just those currently ACTIVE:
        // an accrual posted in arrears must still include someone who worked the
        // period but has since exited (their gratuity for that period is real).
        // Window = joined on/before periodEnd AND not exited before periodStart.
        List<Employee> employed = employeeRepository.findByOrgIdAndIsDeletedFalse(orgId).stream()
                .filter(e -> e.getDateOfJoining() != null && !e.getDateOfJoining().isAfter(periodEnd))
                .filter(e -> e.getDateOfExit() == null || !e.getDateOfExit().isBefore(periodStart))
                .toList();
        List<Map<String, Object>> rows = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Employee emp : employed) {
            BigDecimal basicPlusDa = resolveBasicPlusDaOrNull(emp.getId(), periodEnd);
            if (basicPlusDa == null || basicPlusDa.signum() <= 0) {
                continue;
            }
            BigDecimal slice = monthlyAccrual(emp.getDateOfJoining(), periodEnd, basicPlusDa);
            if (slice.signum() <= 0) {
                continue;
            }
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("employeeId", emp.getId());
            row.put("employeeCode", emp.getEmployeeCode());
            row.put("employeeName", emp.getFullName());
            row.put("basicPlusDa", basicPlusDa);
            row.put("monthlyAccrual", slice);
            rows.add(row);
            total = total.add(slice);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("periodYear", year);
        result.put("periodMonth", month);
        result.put("employeeCount", rows.size());
        result.put("totalAmount", total.setScale(2, RoundingMode.HALF_UP));
        result.put("lines", rows);
        return result;
    }

    // ── Salary resolution ───────────────────────────────────────────────────

    /** Basic + DA from the active structure; throws if none resolvable. */
    public BigDecimal resolveMonthlyBasicPlusDa(UUID employeeId, LocalDate asOf) {
        BigDecimal basicPlusDa = resolveBasicPlusDaOrNull(employeeId, asOf);
        if (basicPlusDa == null || basicPlusDa.signum() <= 0) {
            throw new BusinessException(
                    "Salary structure has no BASIC/DA component or gross — gratuity needs a positive wage",
                    "GRATUITY_NO_BASIC", HttpStatus.BAD_REQUEST);
        }
        return basicPlusDa;
    }

    private BigDecimal resolveBasicPlusDaOrNull(UUID employeeId, LocalDate asOf) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeSalaryStructure structure = salaryStructureRepository
                .findByOrgIdAndEmployeeIdAndStatusOrderByEffectiveFromDesc(orgId, employeeId, "ACTIVE")
                .stream()
                .filter(s -> !s.getEffectiveFrom().isAfter(asOf))
                .filter(s -> s.getEffectiveTo() == null || !s.getEffectiveTo().isBefore(asOf))
                .findFirst()
                .orElse(null);
        if (structure == null) {
            return null;
        }
        // India gratuity wage = basic + dearness allowance (§2(s) "wages").
        BigDecimal sum = structure.getLines().stream()
                .filter(l -> {
                    String code = l.getSalaryComponent() != null
                            ? l.getSalaryComponent().getCode() : null;
                    return "BASIC".equalsIgnoreCase(code) || "DA".equalsIgnoreCase(code);
                })
                .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (sum.signum() > 0) {
            return sum;
        }
        // No BASIC/DA lines modelled — fall back to gross (some SMBs run a
        // single-line package). Overstates the provision slightly but never
        // silently zeroes it.
        return structure.getGrossMonthly();
    }

    /**
     * Self-heal a missing India gratuity GL (2080/5130) instead of failing the
     * accrual over a chart that predates V25. Mirror of the Gulf
     * {@code ensureGulfAccount}; the boot-time template repair sweep re-parents
     * it on the next restart.
     */
    private void ensureIndiaGratuityAccount(UUID orgId, String code, String label) {
        if (accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code).isPresent()) {
            return;
        }
        boolean expense = code.startsWith("5");
        Account account = Account.builder()
                .code(code).name(label)
                .type(expense ? "EXPENSE" : "LIABILITY")
                .subType(expense ? "OPERATING_EXPENSE" : "CURRENT_LIABILITY")
                .level(2).currency("INR").active(true).build();
        account.setOrgId(orgId);
        accountRepository.save(account);
        log.warn("Self-healed missing India gratuity account {} ({}) for org {}", code, label, orgId);
    }
}
