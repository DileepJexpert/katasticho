package com.katasticho.erp.tax.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipLineRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import com.katasticho.erp.tax.dto.SalaryTdsLineRow;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SalaryTdsServiceTest {

    @Mock private PayrollRunRepository runRepo;
    @Mock private PayslipRepository payslipRepo;
    @Mock private PayslipLineRepository lineRepo;
    @Mock private EmployeeRepository employeeRepo;
    @Mock private OrganisationRepository orgRepo;
    @Mock private OrgSettingsService settings;
    private SalaryTdsService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID empA = UUID.randomUUID();
    private final UUID empB = UUID.randomUUID();
    private final UUID runId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new SalaryTdsService(runRepo, payslipRepo, lineRepo, employeeRepo, orgRepo, settings);
        TenantContext.setCurrentOrgId(orgId);
        // deductor block: settings return their default, org master absent
        when(settings.get(eq(orgId), any(), any())).thenAnswer(i -> i.getArgument(2));
        when(orgRepo.findById(orgId)).thenReturn(Optional.empty());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private PayrollRun run(UUID id, LocalDate periodStart) {
        return PayrollRun.builder().id(id).orgId(orgId)
                .periodStart(periodStart).periodEnd(periodStart.plusMonths(1).minusDays(1))
                .status("POSTED").build();
    }

    private Payslip payslip(UUID employeeId, String gross) {
        return Payslip.builder().orgId(orgId).payrollRunId(runId)
                .employeeId(employeeId).grossPay(new BigDecimal(gross)).build();
    }

    @Test
    void form24q_aggregatesPerEmployeeAndFlagsMissingPan() {
        when(runRepo.findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(
                eq(orgId), eq("POSTED"), eq(LocalDate.of(2026, 4, 1)), eq(LocalDate.of(2026, 6, 30))))
                .thenReturn(List.of(run(runId, LocalDate.of(2026, 5, 1))));
        when(payslipRepo.findByOrgIdAndPayrollRunIdIn(eq(orgId), any()))
                .thenReturn(List.of(payslip(empA, "50000"), payslip(empB, "30000")));
        when(lineRepo.findLineRowsForRuns(eq(orgId), any())).thenReturn(List.of(
                new SalaryTdsLineRow(empA, "TDS", "DEDUCTION", new BigDecimal("5000"), runId),
                new SalaryTdsLineRow(empB, "PT", "DEDUCTION", new BigDecimal("200"), runId)));
        when(employeeRepo.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any())).thenReturn(List.of(
                Employee.builder().id(empA).orgId(orgId).fullName("Asha").pan("ABCPA1234A").build(),
                Employee.builder().id(empB).orgId(orgId).fullName("Bharat").build())); // no PAN

        Map<String, Object> r = service.form24q(2026, 1);

        assertEquals("24Q", r.get("form"));
        assertEquals("Q1", r.get("quarter"));
        assertEquals(2, r.get("deducteeCount"));
        assertEquals(0, new BigDecimal("80000").compareTo((BigDecimal) r.get("totalAmountPaid")));
        assertEquals(0, new BigDecimal("5000").compareTo((BigDecimal) r.get("totalTdsDeducted")));
        assertEquals(1, r.get("missingPanCount"));
        assertNotNull(r.get("warning"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void form16_buildsQuarterwisePartAandSalaryPartB() {
        UUID may = UUID.randomUUID();
        UUID nov = UUID.randomUUID();
        when(employeeRepo.findByIdAndOrgIdAndIsDeletedFalse(empA, orgId)).thenReturn(Optional.of(
                Employee.builder().id(empA).orgId(orgId).fullName("Asha").pan("ABCPA1234A")
                        .designation("Manager").build()));
        when(runRepo.findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(
                eq(orgId), eq("POSTED"), eq(LocalDate.of(2026, 4, 1)), eq(LocalDate.of(2027, 3, 31))))
                .thenReturn(List.of(run(may, LocalDate.of(2026, 5, 1)), run(nov, LocalDate.of(2026, 11, 1))));
        when(lineRepo.findLineRowsForRuns(eq(orgId), any())).thenReturn(List.of(
                new SalaryTdsLineRow(empA, "BASIC", "EARNING", new BigDecimal("40000"), may),
                new SalaryTdsLineRow(empA, "TDS", "DEDUCTION", new BigDecimal("5000"), may),
                new SalaryTdsLineRow(empA, "PT", "DEDUCTION", new BigDecimal("200"), may),
                new SalaryTdsLineRow(empA, "BASIC", "EARNING", new BigDecimal("40000"), nov),
                new SalaryTdsLineRow(empA, "TDS", "DEDUCTION", new BigDecimal("3000"), nov),
                new SalaryTdsLineRow(empA, "PT", "DEDUCTION", new BigDecimal("200"), nov)));

        Map<String, Object> r = service.form16(empA, 2026);

        assertEquals("16", r.get("form"));
        assertEquals("2027-28", r.get("assessmentYear"));
        assertEquals(0, new BigDecimal("8000").compareTo((BigDecimal) r.get("totalTdsDeducted")));

        List<Map<String, Object>> partA = (List<Map<String, Object>>) r.get("partA");
        assertEquals(4, partA.size());
        assertEquals(0, new BigDecimal("5000").compareTo((BigDecimal) partA.get(0).get("tdsDeducted"))); // Q1
        assertEquals(0, BigDecimal.ZERO.compareTo((BigDecimal) partA.get(1).get("tdsDeducted")));         // Q2
        assertEquals(0, new BigDecimal("3000").compareTo((BigDecimal) partA.get(2).get("tdsDeducted"))); // Q3
        assertEquals(0, BigDecimal.ZERO.compareTo((BigDecimal) partA.get(3).get("tdsDeducted")));         // Q4

        Map<String, Object> partB = (Map<String, Object>) r.get("partB");
        assertEquals(0, new BigDecimal("80000").compareTo((BigDecimal) partB.get("grossSalary")));
        assertEquals(0, new BigDecimal("400").compareTo((BigDecimal) partB.get("professionalTax")));
        assertEquals(0, new BigDecimal("8000").compareTo((BigDecimal) partB.get("totalTaxDeducted")));
    }

    @Test
    @SuppressWarnings("unchecked")
    void register_listsEmployeesWithTdsAndExcludesZero() {
        when(runRepo.findByOrgIdAndStatusAndPeriodStartBetweenOrderByPeriodStart(
                eq(orgId), eq("POSTED"), any(), any()))
                .thenReturn(List.of(run(runId, LocalDate.of(2026, 5, 1))));
        when(payslipRepo.findByOrgIdAndPayrollRunIdIn(eq(orgId), any()))
                .thenReturn(List.of(payslip(empA, "50000"), payslip(empB, "30000")));
        when(lineRepo.findLineRowsForRuns(eq(orgId), any())).thenReturn(List.of(
                new SalaryTdsLineRow(empA, "TDS", "DEDUCTION", new BigDecimal("5000"), runId)));
        when(employeeRepo.findByOrgIdAndIsDeletedFalseAndIdIn(eq(orgId), any())).thenReturn(List.of(
                Employee.builder().id(empA).orgId(orgId).fullName("Asha").pan("ABCPA1234A").build(),
                Employee.builder().id(empB).orgId(orgId).fullName("Bharat").build()));

        List<Map<String, Object>> rows = service.register(
                LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31));

        assertEquals(1, rows.size()); // empB has zero TDS -> excluded
        assertEquals("Asha", rows.get(0).get("employeeName"));
        assertEquals(0, new BigDecimal("5000").compareTo((BigDecimal) rows.get(0).get("tdsDeducted")));
    }

    @Test
    void quarterIndexOf_mapsMonthsToFyQuarters() {
        assertEquals(0, SalaryTdsService.quarterIndexOf(LocalDate.of(2026, 5, 1), 2026));   // Q1
        assertEquals(2, SalaryTdsService.quarterIndexOf(LocalDate.of(2026, 11, 1), 2026));  // Q3
        assertEquals(3, SalaryTdsService.quarterIndexOf(LocalDate.of(2027, 1, 1), 2026));   // Q4
        assertEquals(-1, SalaryTdsService.quarterIndexOf(LocalDate.of(2025, 3, 1), 2026));  // outside FY
    }
}
