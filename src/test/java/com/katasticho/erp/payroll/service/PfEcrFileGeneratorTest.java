package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.entity.PayslipLine;
import com.katasticho.erp.payroll.entity.SalaryComponent;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PfEcrFileGeneratorTest {

    @Mock private PayrollRunRepository runRepo;
    @Mock private PayslipRepository payslipRepo;
    @Mock private EmployeeRepository employeeRepo;

    private PfEcrFileGenerator gen;
    private final UUID orgId = UUID.randomUUID();
    private final UUID runId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        gen = new PfEcrFileGenerator(runRepo, payslipRepo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    // ── Wage cap + contribution math ───────────────────────────────

    @Test
    void caps_pf_wages_at_15000_and_computes_consistent_contributions() {
        PayrollRun run = junRun();
        Employee emp = employee("100123456789", "Ramesh Kumar", LocalDate.of(1990, 1, 1));
        Payslip ps = payslip(emp, "60000", "30000", "0"); // basic 30k > cap

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String ecr = gen.generate(runId).trim();
        String[] cols = ecr.split("#~#");

        // Expected (basic capped to 15000):
        //   EPF wages 15000, EPS 15000, EDLI 15000
        //   EPF contri (employee 12%) = 1800
        //   EPS contri (8.33%) = 15000 * 0.0833 = 1249.5 → 1250 rupees
        //   EPF&EPS diff = 1800 - 1250 = 550
        assertEquals("100123456789", cols[0]);
        assertEquals("Ramesh Kumar", cols[1]);
        assertEquals("60000", cols[2]);       // gross
        assertEquals("15000", cols[3]);       // EPF wages capped
        assertEquals("15000", cols[4]);       // EPS wages capped
        assertEquals("15000", cols[5]);       // EDLI wages capped
        assertEquals("1800", cols[6]);        // EPF contri = 12% × 15000
        assertEquals("1250", cols[7]);        // EPS contri = round(8.33% × 15000)
        assertEquals("550", cols[8]);         // EPF&EPS diff
        assertEquals("0", cols[9]);           // NCP days
        assertEquals("0", cols[10]);          // Refund of advances
    }

    @Test
    void uses_actual_basic_when_below_cap() {
        PayrollRun run = junRun();
        Employee emp = employee("200234567890", "Sita Devi", LocalDate.of(1992, 5, 1));
        Payslip ps = payslip(emp, "20000", "10000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).trim().split("#~#");
        assertEquals("10000", cols[3]); // EPF wages = actual basic
        assertEquals("1200", cols[6]);  // 12% × 10000
        assertEquals("833", cols[7]);   // round(8.33% × 10000) = 833
        assertEquals("367", cols[8]);   // 1200 - 833
    }

    // ── EPS age ceiling ────────────────────────────────────────────

    @Test
    void employee_over_58_gets_zero_eps_wages_full_pf_to_employer() {
        PayrollRun run = junRun();
        // Employee aged 65 — definitely past EPS ceiling
        Employee emp = employee("300345678901", "Hari Singh", LocalDate.of(1960, 6, 15));
        Payslip ps = payslip(emp, "40000", "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).trim().split("#~#");
        assertEquals("15000", cols[3]); // EPF wages still apply
        assertEquals("0", cols[4]);      // EPS wages = 0 (over 58)
        assertEquals("1800", cols[6]);   // EPF contri unchanged
        assertEquals("0", cols[7]);      // EPS contri = 0
        assertEquals("1800", cols[8]);   // EPF&EPS diff = all of employer 12%
    }

    // ── NCP days ───────────────────────────────────────────────────

    @Test
    void ncp_days_carry_through_from_lopDays_rounded_to_integer() {
        PayrollRun run = junRun();
        Employee emp = employee("400456789012", "Ravi N", LocalDate.of(1990, 1, 1));
        Payslip ps = payslip(emp, "50000", "25000", "3.5");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).trim().split("#~#");
        assertEquals("4", cols[9]); // 3.5 rounds half-up to 4
    }

    // ── Skip rules ─────────────────────────────────────────────────

    @Test
    void skips_employees_without_uan_with_warn_but_keeps_others() {
        PayrollRun run = junRun();
        Employee withUan = employee("500567890123", "Anjali", LocalDate.of(1995, 1, 1));
        Employee withoutUan = employee(null, "Mukesh (no UAN)", LocalDate.of(1990, 1, 1));
        Payslip ps1 = payslip(withUan, "30000", "15000", "0");
        Payslip ps2 = payslip(withoutUan, "30000", "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(ps1, ps2));

        String ecr = gen.generate(runId);
        String[] lines = ecr.split("\r\n");
        assertEquals(1, lines.length, "no-UAN row must be omitted");
        assertTrue(lines[0].startsWith("500567890123"));
    }

    @Test
    void skips_non_pf_applicable_employees() {
        PayrollRun run = junRun();
        Employee notPf = employee("600678901234", "Excluded", LocalDate.of(1990, 1, 1));
        notPf.setPfApplicable(false);
        Payslip ps = payslip(notPf, "30000", "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        assertEquals("", gen.generate(runId));
    }

    @Test
    void empty_run_returns_empty_string_no_throw() {
        when(runRepo.findById(runId))
                .thenReturn(Optional.of(junRun()));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of());

        assertEquals("", gen.generate(runId));
    }

    @Test
    void filename_uses_period_yyyy_mm() {
        assertEquals("ECR-2026-06.txt", gen.filename(junRun()));
    }

    @Test
    void uan_strips_non_digits_and_name_strips_separator() {
        PayrollRun run = junRun();
        Employee emp = employee("100-123-456-789", "Name#~#With#~#Sep", LocalDate.of(1990, 1, 1));
        Payslip ps = payslip(emp, "30000", "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).trim().split("#~#");
        assertEquals("100123456789", cols[0]);
        assertEquals("Name With Sep", cols[1]);
    }

    // ── helpers ────────────────────────────────────────────────────

    private PayrollRun junRun() {
        PayrollRun r = new PayrollRun();
        r.setId(runId);
        r.setOrgId(orgId);
        r.setPeriodStart(LocalDate.of(2026, 6, 1));
        r.setPeriodEnd(LocalDate.of(2026, 6, 30));
        return r;
    }

    private Employee employee(String uan, String name, LocalDate dob) {
        Employee e = new Employee();
        e.setId(UUID.randomUUID());
        e.setOrgId(orgId);
        e.setUan(uan);
        e.setFullName(name);
        e.setDateOfBirth(dob);
        e.setPfApplicable(true);
        return e;
    }

    private Payslip payslip(Employee emp, String gross, String basic, String lop) {
        Payslip ps = new Payslip();
        ps.setOrgId(orgId);
        ps.setEmployeeId(emp.getId());
        ps.setEmployee(emp);
        ps.setPayrollRunId(runId);
        ps.setGrossPay(new BigDecimal(gross));
        ps.setLopDays(new BigDecimal(lop));

        SalaryComponent basicC = new SalaryComponent();
        basicC.setCode("BASIC");
        PayslipLine basicLine = PayslipLine.builder()
                .salaryComponent(basicC)
                .componentType("EARNING")
                .amount(new BigDecimal(basic))
                .build();
        ps.setLines(new java.util.ArrayList<>(List.of(basicLine)));
        return ps;
    }
}
