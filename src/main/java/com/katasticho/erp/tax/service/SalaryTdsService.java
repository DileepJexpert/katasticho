package com.katasticho.erp.tax.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipLineRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import com.katasticho.erp.tax.dto.SalaryTdsLineRow;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Salary TDS compliance (the salary-side mirror of {@link TdsService}'s 26Q).
 *
 * <p>Salary TDS is deducted inside payroll: each payslip carries a {@code TDS}
 * deduction line. This service rolls those up into:
 * <ul>
 *   <li><b>Form 24Q</b> — the quarterly salary-TDS return: deductee (employee)
 *       wise salary paid + TDS deducted for a quarter.</li>
 *   <li><b>Form 16</b> — the annual employee TDS certificate: Part A (quarter-wise
 *       TDS for the FY) + Part B (salary breakup and total deductions).</li>
 *   <li>A salary-TDS register for the monthly ITNS-281 deposit.</li>
 * </ul>
 * Only <b>POSTED</b> payroll runs are counted (TDS is real once the run is
 * finalised and its journal — including TDS Payable — is posted). The FY runs
 * April–March; quarters are Q1 Apr–Jun … Q4 Jan–Mar. The deductor's TAN/PAN/name
 * come from org settings ({@code tax.deductor_tan} / {@code tax.deductor_pan} /
 * {@code tax.deductor_name}), falling back to the organisation master.
 */
@Service
@RequiredArgsConstructor
public class SalaryTdsService {

    private static final String TDS_CODE = "TDS";
    private static final String PT_CODE = "PT";
    private static final String POSTED = "POSTED";
    private static final String EARNING = "EARNING";

    static final String SETTING_TAN = "tax.deductor_tan";
    static final String SETTING_PAN = "tax.deductor_pan";
    static final String SETTING_NAME = "tax.deductor_name";

    private final PayrollRunRepository payrollRunRepository;
    private final PayslipRepository payslipRepository;
    private final PayslipLineRepository payslipLineRepository;
    private final EmployeeRepository employeeRepository;
    private final OrganisationRepository organisationRepository;
    private final OrgSettingsService orgSettingsService;

    // ── Form 24Q (quarterly salary-TDS return) ───────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> form24q(int fyStartYear, int quarter) {
        UUID orgId = requireOrgId();
        QuarterRange q = quarterRange(fyStartYear, quarter);

        List<PayrollRun> runs = postedRuns(orgId, q.from(), q.to());
        Aggregate agg = aggregate(orgId, runs);

        Map<UUID, Employee> employees = loadEmployees(orgId, agg.grossByEmployee.keySet());

        List<Map<String, Object>> deductees = new ArrayList<>();
        BigDecimal totalPaid = BigDecimal.ZERO, totalTds = BigDecimal.ZERO;
        int missingPan = 0;

        for (UUID empId : agg.grossByEmployee.keySet()) {
            Employee e = employees.get(empId);
            BigDecimal paid = nz(agg.grossByEmployee.get(empId));
            BigDecimal tds = nz(agg.tdsByEmployee.get(empId));
            String pan = e != null ? nvl(e.getPan()) : "";
            if (pan.isBlank()) missingPan++;

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("employeeId", empId);
            row.put("employeeCode", e != null ? nvl(e.getEmployeeCode()) : "");
            row.put("deducteeName", e != null ? nvl(e.getFullName()) : "");
            row.put("deducteePan", pan);
            row.put("amountPaid", paid);
            row.put("tdsDeducted", tds);
            row.put("monthCount", agg.monthsByEmployee.getOrDefault(empId, 0));
            deductees.add(row);
            totalPaid = totalPaid.add(paid);
            totalTds = totalTds.add(tds);
        }
        deductees.sort((a, b) -> ((String) a.get("deducteeName"))
                .compareToIgnoreCase((String) b.get("deducteeName")));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("form", "24Q");
        result.put("fy", fyLabel(fyStartYear));
        result.put("quarter", "Q" + quarter);
        result.put("periodFrom", q.from());
        result.put("periodTo", q.to());
        result.put("deductor", deductor(orgId));
        result.put("deducteeCount", deductees.size());
        result.put("totalAmountPaid", totalPaid);
        result.put("totalTdsDeducted", totalTds);
        result.put("missingPanCount", missingPan);
        if (missingPan > 0) {
            result.put("warning", missingPan + " employee(s) have no PAN on file — "
                    + "TDS at 20% applies without PAN and the return will be flagged.");
        }
        result.put("deductees", deductees);
        return result;
    }

    // ── Form 16 (annual employee TDS certificate) ────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> form16(UUID employeeId, int fyStartYear) {
        UUID orgId = requireOrgId();
        Employee employee = employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", employeeId));

        LocalDate fyFrom = LocalDate.of(fyStartYear, 4, 1);
        LocalDate fyTo = LocalDate.of(fyStartYear + 1, 3, 31);
        List<PayrollRun> runs = postedRuns(orgId, fyFrom, fyTo);
        Map<UUID, PayrollRun> runById = new HashMap<>();
        runs.forEach(r -> runById.put(r.getId(), r));

        List<SalaryTdsLineRow> rows = runs.isEmpty()
                ? List.of()
                : payslipLineRepository.findLineRowsForRuns(orgId,
                runs.stream().map(PayrollRun::getId).toList());

        // Part A: quarter-wise TDS for THIS employee.
        BigDecimal[] tdsByQuarter = new BigDecimal[]{
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO};
        // Part B: salary breakup for THIS employee (component code → amount).
        BigDecimal grossEarnings = BigDecimal.ZERO;
        BigDecimal totalTds = BigDecimal.ZERO;
        BigDecimal professionalTax = BigDecimal.ZERO;
        Map<String, BigDecimal> earningsByComponent = new LinkedHashMap<>();
        Map<String, BigDecimal> deductionsByComponent = new LinkedHashMap<>();

        for (SalaryTdsLineRow r : rows) {
            if (!employeeId.equals(r.employeeId())) continue;
            BigDecimal amt = nz(r.amount());
            String code = nvl(r.componentCode());
            if (EARNING.equalsIgnoreCase(r.componentType())) {
                grossEarnings = grossEarnings.add(amt);
                earningsByComponent.merge(code, amt, BigDecimal::add);
            } else {
                deductionsByComponent.merge(code, amt, BigDecimal::add);
                if (TDS_CODE.equalsIgnoreCase(code)) {
                    totalTds = totalTds.add(amt);
                    PayrollRun run = runById.get(r.payrollRunId());
                    if (run != null) {
                        int qi = quarterIndexOf(run.getPeriodStart(), fyStartYear);
                        if (qi >= 0) tdsByQuarter[qi] = tdsByQuarter[qi].add(amt);
                    }
                } else if (PT_CODE.equalsIgnoreCase(code)) {
                    professionalTax = professionalTax.add(amt);
                }
            }
        }

        List<Map<String, Object>> partA = new ArrayList<>();
        for (int qi = 0; qi < 4; qi++) {
            Map<String, Object> qrow = new LinkedHashMap<>();
            qrow.put("quarter", "Q" + (qi + 1));
            qrow.put("tdsDeducted", tdsByQuarter[qi]);
            partA.add(qrow);
        }

        Map<String, Object> partB = new LinkedHashMap<>();
        partB.put("grossSalary", grossEarnings);
        partB.put("earningsByComponent", earningsByComponent);
        partB.put("professionalTax", professionalTax);
        partB.put("deductionsByComponent", deductionsByComponent);
        partB.put("totalTaxDeducted", totalTds);

        Map<String, Object> employeeBlock = new LinkedHashMap<>();
        employeeBlock.put("employeeId", employee.getId());
        employeeBlock.put("employeeCode", nvl(employee.getEmployeeCode()));
        employeeBlock.put("name", nvl(employee.getFullName()));
        employeeBlock.put("pan", nvl(employee.getPan()));
        employeeBlock.put("designation", nvl(employee.getDesignation()));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("form", "16");
        result.put("fy", fyLabel(fyStartYear));
        result.put("assessmentYear", (fyStartYear + 1) + "-" + ((fyStartYear + 2) % 100));
        result.put("deductor", deductor(orgId));
        result.put("employee", employeeBlock);
        result.put("partA", partA);
        result.put("partB", partB);
        result.put("totalTdsDeducted", totalTds);
        if (nvl(employee.getPan()).isBlank()) {
            result.put("warning", "Employee has no PAN on file — Form 16 cannot be validly issued without it.");
        }
        return result;
    }

    // ── Salary-TDS register (for the deposit challan) ────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> register(LocalDate from, LocalDate to) {
        UUID orgId = requireOrgId();
        List<PayrollRun> runs = postedRuns(orgId, from, to);
        Aggregate agg = aggregate(orgId, runs);
        Map<UUID, Employee> employees = loadEmployees(orgId, agg.tdsByEmployee.keySet());

        List<Map<String, Object>> rows = new ArrayList<>();
        for (UUID empId : agg.tdsByEmployee.keySet()) {
            BigDecimal tds = nz(agg.tdsByEmployee.get(empId));
            if (tds.signum() <= 0) continue;
            Employee e = employees.get(empId);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("employeeId", empId);
            row.put("employeeCode", e != null ? nvl(e.getEmployeeCode()) : "");
            row.put("employeeName", e != null ? nvl(e.getFullName()) : "");
            row.put("pan", e != null ? nvl(e.getPan()) : "");
            row.put("salaryPaid", nz(agg.grossByEmployee.get(empId)));
            row.put("tdsDeducted", tds);
            rows.add(row);
        }
        rows.sort((a, b) -> ((String) a.get("employeeName"))
                .compareToIgnoreCase((String) b.get("employeeName")));
        return rows;
    }

    // ── Aggregation ──────────────────────────────────────────────────────

    private static final class Aggregate {
        final Map<UUID, BigDecimal> grossByEmployee = new LinkedHashMap<>();
        final Map<UUID, BigDecimal> tdsByEmployee = new LinkedHashMap<>();
        final Map<UUID, Integer> monthsByEmployee = new HashMap<>();
    }

    private Aggregate aggregate(UUID orgId, List<PayrollRun> runs) {
        Aggregate agg = new Aggregate();
        if (runs.isEmpty()) return agg;
        List<UUID> runIds = runs.stream().map(PayrollRun::getId).toList();

        // Gross + month count from payslip headers.
        for (Payslip p : payslipRepository.findByOrgIdAndPayrollRunIdIn(orgId, runIds)) {
            agg.grossByEmployee.merge(p.getEmployeeId(), nz(p.getGrossPay()), BigDecimal::add);
            agg.tdsByEmployee.putIfAbsent(p.getEmployeeId(), BigDecimal.ZERO);
            agg.monthsByEmployee.merge(p.getEmployeeId(), 1, Integer::sum);
        }
        // TDS from the TDS deduction lines.
        for (SalaryTdsLineRow r : payslipLineRepository.findLineRowsForRuns(orgId, runIds)) {
            if (TDS_CODE.equalsIgnoreCase(nvl(r.componentCode()))) {
                agg.tdsByEmployee.merge(r.employeeId(), nz(r.amount()), BigDecimal::add);
            }
        }
        return agg;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private List<PayrollRun> postedRuns(UUID orgId, LocalDate from, LocalDate to) {
        return payrollRunRepository
                .findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(orgId, POSTED, from, to);
    }

    private Map<UUID, Employee> loadEmployees(UUID orgId, Collection<UUID> ids) {
        if (ids.isEmpty()) return Map.of();
        Map<UUID, Employee> map = new HashMap<>();
        employeeRepository.findByOrgIdAndIsDeletedFalseAndIdIn(orgId, ids)
                .forEach(e -> map.put(e.getId(), e));
        return map;
    }

    private Map<String, Object> deductor(UUID orgId) {
        Organisation org = organisationRepository.findById(orgId).orElse(null);
        String name = orgSettingsService.get(orgId, SETTING_NAME, "");
        if (name.isBlank() && org != null) name = nvl(org.getName());
        String pan = orgSettingsService.get(orgId, SETTING_PAN, "");
        if (pan.isBlank() && org != null) pan = nvl(org.getTaxId());
        String tan = orgSettingsService.get(orgId, SETTING_TAN, "");

        Map<String, Object> d = new LinkedHashMap<>();
        d.put("name", name);
        d.put("tan", tan);
        d.put("pan", pan);
        if (tan.isBlank()) {
            d.put("note", "Set the deductor TAN (tax.deductor_tan) to file Form 24Q/16.");
        }
        return d;
    }

    record QuarterRange(LocalDate from, LocalDate to) {}

    static QuarterRange quarterRange(int fyStartYear, int quarter) {
        if (quarter < 1 || quarter > 4) {
            throw new BusinessException("Quarter must be 1-4", "TDS_BAD_QUARTER");
        }
        LocalDate from = switch (quarter) {
            case 1 -> LocalDate.of(fyStartYear, 4, 1);
            case 2 -> LocalDate.of(fyStartYear, 7, 1);
            case 3 -> LocalDate.of(fyStartYear, 10, 1);
            default -> LocalDate.of(fyStartYear + 1, 1, 1);
        };
        return new QuarterRange(from, from.plusMonths(3).minusDays(1));
    }

    /** 0-based quarter index (Q1=0…Q4=3) of a date within the given FY, or -1 if outside. */
    static int quarterIndexOf(LocalDate date, int fyStartYear) {
        LocalDate fyFrom = LocalDate.of(fyStartYear, 4, 1);
        LocalDate fyTo = LocalDate.of(fyStartYear + 1, 3, 31);
        if (date.isBefore(fyFrom) || date.isAfter(fyTo)) return -1;
        int monthsFromApril = (date.getYear() - fyStartYear) * 12 + (date.getMonthValue() - 4);
        return monthsFromApril / 3;
    }

    private static String fyLabel(int fyStartYear) {
        return fyStartYear + "-" + ((fyStartYear + 1) % 100);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String nvl(String s) {
        return s == null ? "" : s;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
