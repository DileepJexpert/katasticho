package com.katasticho.erp.payroll.gulf;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeSalaryStructure;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.EmployeeSalaryStructureRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/**
 * End-of-service gratuity calculations for Gulf orgs (UAE + Oman). India's
 * payroll equivalent is PF/ESI/PT/LWF; the Gulf substitutes a single
 * accrued-then-paid-at-termination gratuity instead.
 *
 * <h2>UAE — Federal Decree-Law No. 33 of 2021</h2>
 * <ul>
 *   <li>Service &lt; 1 year → nil.</li>
 *   <li>21 days of basic wage per year for the first 5 years.</li>
 *   <li>30 days of basic wage per year for each year after 5.</li>
 *   <li>Partial years pro-rated by the months served.</li>
 *   <li>Total gratuity capped at two years' total wage.</li>
 * </ul>
 *
 * <h2>Oman — Labour Law (Royal Decree 35/2003)</h2>
 * <ul>
 *   <li>Service &lt; 1 year → nil.</li>
 *   <li>15 days of basic wage per year for the first 3 years.</li>
 *   <li>30 days (one month) of basic wage per year for each year after 3.</li>
 *   <li>Partial years pro-rated. Same 24-month cap applies.</li>
 * </ul>
 *
 * <p>Daily wage = monthly basic ÷ 30 in both jurisdictions. The two countries
 * differ only in the breakpoint year (5 vs 3) and the first-tier days (21 vs
 * 15) — kept as a single method to avoid duplicating the cap + nil-year guard.
 *
 * <p>The calculator is pure math — no DB writes. A future commit will accrue
 * the monthly slice into a {@code gratuity_provision} liability and pay out
 * the running balance on termination.
 */
@Service
@RequiredArgsConstructor
public class GulfPayrollService {

    private static final BigDecimal DAYS_PER_MONTH = new BigDecimal("30");
    private static final BigDecimal MONTHS_PER_YEAR = new BigDecimal("12");
    private static final BigDecimal CAP_MONTHS = new BigDecimal("24");

    private final EmployeeRepository employeeRepository;
    private final EmployeeSalaryStructureRepository salaryStructureRepository;
    private final CountryAccessService countryAccessService;
    private final Clock clock;

    /**
     * Compute gratuity from the employee's {@code dateOfJoining} → asOf date,
     * pulling the basic from the currently effective salary structure.
     *
     * @param employeeId payroll employee id
     * @param asOf       end date for the service period; {@code null} = today
     */
    @Transactional(readOnly = true)
    public GratuityResult computeFor(UUID employeeId, LocalDate asOf) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Employee employee = employeeRepository.findById(employeeId)
                .filter(e -> orgId.equals(e.getOrgId()) && !e.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("Employee", employeeId));

        if (employee.getDateOfJoining() == null) {
            throw new BusinessException(
                    "Employee has no date of joining — gratuity needs a service start date",
                    "GRATUITY_NO_JOIN_DATE", HttpStatus.BAD_REQUEST);
        }

        LocalDate endDate = asOf != null
                ? asOf
                : (employee.getDateOfExit() != null
                        ? employee.getDateOfExit()
                        : LocalDate.now(clock));

        BigDecimal monthlyBasic = resolveMonthlyBasic(employeeId, endDate);

        return compute(countryAccessService.currentCountry(),
                employee.getDateOfJoining(), endDate, monthlyBasic);
    }

    /**
     * Pure math entry point — useful for the gratuity-provision accrual that
     * the payroll calc loop will call once-per-month (deferred to a follow-up
     * commit). Both inputs are required; both countries cap at 24 months wage.
     */
    public GratuityResult compute(String country, LocalDate from, LocalDate to, BigDecimal monthlyBasic) {
        if (country == null) {
            throw new BusinessException("Country is required",
                    "GRATUITY_NO_COUNTRY", HttpStatus.BAD_REQUEST);
        }
        if (from == null || to == null || !to.isAfter(from)) {
            throw new BusinessException(
                    "Service end date must be after start date",
                    "GRATUITY_INVALID_RANGE", HttpStatus.BAD_REQUEST);
        }
        if (monthlyBasic == null || monthlyBasic.signum() <= 0) {
            throw new BusinessException(
                    "Monthly basic must be positive",
                    "GRATUITY_NO_BASIC", HttpStatus.BAD_REQUEST);
        }

        String code = country.trim().toUpperCase();
        // Years calculated from completed months + partial-month fraction.
        // Using raw days / 365 picks up leap years as noise — labour law speaks
        // in months. Jan 1 → Jan 1 across years is "exactly N years", not
        // "N.003 years because of a leap day".
        long fullMonths = ChronoUnit.MONTHS.between(from, to);
        LocalDate afterFullMonths = from.plusMonths(fullMonths);
        long extraDays = ChronoUnit.DAYS.between(afterFullMonths, to);
        int daysInLastMonth = afterFullMonths.lengthOfMonth();
        BigDecimal monthsExact = BigDecimal.valueOf(fullMonths)
                .add(BigDecimal.valueOf(extraDays)
                        .divide(BigDecimal.valueOf(daysInLastMonth), 6, RoundingMode.HALF_UP));
        BigDecimal yearsExact = monthsExact.divide(MONTHS_PER_YEAR, 6, RoundingMode.HALF_UP);
        BigDecimal dailyBasic = monthlyBasic.divide(DAYS_PER_MONTH, 4, RoundingMode.HALF_UP);

        // Both jurisdictions: nil for first year of service.
        if (yearsExact.compareTo(BigDecimal.ONE) < 0) {
            return new GratuityResult(code, yearsExact, dailyBasic,
                    BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                    "No gratuity — service is under 1 year (" + yearsExact + " years)");
        }

        int breakYear;
        int firstTierDays;
        switch (code) {
            case "AE" -> { breakYear = 5; firstTierDays = 21; }
            case "OM" -> { breakYear = 3; firstTierDays = 15; }
            default -> throw new BusinessException(
                    "End-of-service gratuity is only modelled for AE and OM (got " + code + ")",
                    "GRATUITY_UNSUPPORTED_COUNTRY", HttpStatus.BAD_REQUEST);
        }

        BigDecimal entitledDays;
        BigDecimal breakYearBD = BigDecimal.valueOf(breakYear);
        if (yearsExact.compareTo(breakYearBD) <= 0) {
            entitledDays = yearsExact.multiply(BigDecimal.valueOf(firstTierDays));
        } else {
            BigDecimal firstTier = breakYearBD.multiply(BigDecimal.valueOf(firstTierDays));
            BigDecimal beyond = yearsExact.subtract(breakYearBD)
                    .multiply(BigDecimal.valueOf(30));
            entitledDays = firstTier.add(beyond);
        }
        entitledDays = entitledDays.setScale(2, RoundingMode.HALF_UP);

        BigDecimal gross = dailyBasic.multiply(entitledDays)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal cap = monthlyBasic.multiply(CAP_MONTHS)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal capped = gross.min(cap);

        String formula = code.equals("AE")
                ? "UAE: 21 days/yr for first 5 yrs + 30 days/yr beyond; capped at 2 yrs wage"
                : "Oman: 15 days/yr for first 3 yrs + 30 days/yr beyond; capped at 2 yrs wage";

        return new GratuityResult(code, yearsExact, dailyBasic,
                entitledDays, gross, capped, formula);
    }

    private BigDecimal resolveMonthlyBasic(UUID employeeId, LocalDate asOf) {
        UUID orgId = TenantContext.getCurrentOrgId();
        // The currently active structure: effective_from <= asOf AND
        // (effective_to is null OR effective_to >= asOf). The repository
        // returns active structures ordered by effective_from desc; pick the
        // first match.
        EmployeeSalaryStructure structure = salaryStructureRepository
                .findByOrgIdAndEmployeeIdAndStatusOrderByEffectiveFromDesc(orgId, employeeId, "ACTIVE")
                .stream()
                .filter(s -> !s.getEffectiveFrom().isAfter(asOf))
                .filter(s -> s.getEffectiveTo() == null || !s.getEffectiveTo().isBefore(asOf))
                .findFirst()
                .orElseThrow(() -> new BusinessException(
                        "No active salary structure for employee on " + asOf,
                        "GRATUITY_NO_STRUCTURE", HttpStatus.BAD_REQUEST));

        // Prefer an explicit BASIC component on the structure; fall back to
        // grossMonthly (some Gulf orgs model the whole package as a single
        // BASIC for gratuity purposes).
        BigDecimal basic = structure.getLines().stream()
                .filter(l -> {
                    String code = l.getSalaryComponent() != null
                            ? l.getSalaryComponent().getCode() : null;
                    return code != null && code.equalsIgnoreCase("BASIC");
                })
                .map(l -> l.getAmount() != null ? l.getAmount() : BigDecimal.ZERO)
                .findFirst()
                .orElse(null);

        if (basic == null || basic.signum() <= 0) {
            basic = structure.getGrossMonthly();
        }
        if (basic == null || basic.signum() <= 0) {
            throw new BusinessException(
                    "Salary structure has no BASIC component or gross — gratuity needs a positive monthly basic",
                    "GRATUITY_NO_BASIC", HttpStatus.BAD_REQUEST);
        }
        return basic;
    }
}
