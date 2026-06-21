package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
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
class EsiReturnFileGeneratorTest {

    @Mock private PayrollRunRepository runRepo;
    @Mock private PayslipRepository payslipRepo;
    @Mock private EmployeeRepository employeeRepo;

    private EsiReturnFileGenerator gen;
    private final UUID orgId = UUID.randomUUID();
    private final UUID runId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        gen = new EsiReturnFileGenerator(runRepo, payslipRepo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    @Test
    void renders_header_and_one_row_with_correct_columns() {
        PayrollRun run = junRun();
        Employee emp = employee("3112345678901", "Ramesh Kumar");
        Payslip ps = payslip(emp, "18000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String csv = gen.generate(runId);
        String[] lines = csv.split("\r\n");
        assertEquals("IP Number;IP Name;No of Days;Total Monthly Wages;Reason Code;Last Working Day",
                lines[0]);
        // June has 30 days, 0 LOP → 30 days paid; wage 18000
        String[] cols = lines[1].split(";", -1);
        assertEquals("3112345678901", cols[0]);
        assertEquals("Ramesh Kumar", cols[1]);
        assertEquals("30", cols[2]);
        assertEquals("18000", cols[3]);
        assertEquals("0", cols[4]);
        assertEquals("", cols[5], "no last working day mid-employment");
    }

    @Test
    void days_paid_is_month_days_minus_lop_never_negative() {
        PayrollRun run = junRun();
        Employee emp = employee("3122222222222", "Sita");
        Payslip ps = payslip(emp, "15000", "5.5"); // 5.5 → rounds to 6

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).split("\r\n")[1].split(";", -1);
        assertEquals("24", cols[2], "30 - 6 LOP");
    }

    @Test
    void last_working_day_set_when_employee_exited_within_period() {
        PayrollRun run = junRun();
        Employee emp = employee("3133333333333", "Exiting");
        emp.setDateOfExit(LocalDate.of(2026, 6, 15));
        Payslip ps = payslip(emp, "18000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).split("\r\n")[1].split(";", -1);
        assertEquals("15/06/2026", cols[5]);
    }

    @Test
    void last_working_day_NOT_set_when_exit_is_outside_period() {
        PayrollRun run = junRun();
        Employee emp = employee("3144444444444", "Old exit");
        emp.setDateOfExit(LocalDate.of(2026, 3, 31));
        Payslip ps = payslip(emp, "18000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).split("\r\n")[1].split(";", -1);
        assertEquals("", cols[5]);
    }

    @Test
    void skips_employees_without_esi_number() {
        PayrollRun run = junRun();
        Employee withEsi = employee("3155555555555", "WithEsi");
        Employee noEsi = employee(null, "NoEsi");
        Payslip ps1 = payslip(withEsi, "15000", "0");
        Payslip ps2 = payslip(noEsi, "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(ps1, ps2));

        String csv = gen.generate(runId);
        // header + 1 data row only (noEsi skipped)
        assertEquals(2, csv.split("\r\n").length);
    }

    @Test
    void skips_non_esi_applicable_employees() {
        PayrollRun run = junRun();
        Employee emp = employee("3166666666666", "Excluded");
        emp.setEsiApplicable(false);
        Payslip ps = payslip(emp, "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String csv = gen.generate(runId);
        // header only, no data rows
        assertEquals(1, csv.split("\r\n").length);
    }

    @Test
    void name_with_semicolon_is_sanitised() {
        PayrollRun run = junRun();
        Employee emp = employee("3177777777777", "Doe; John");
        Payslip ps = payslip(emp, "15000", "0");

        when(runRepo.findById(runId)).thenReturn(Optional.of(run));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of(ps));

        String[] cols = gen.generate(runId).split("\r\n")[1].split(";", -1);
        assertEquals("Doe  John", cols[1]);
    }

    @Test
    void filename_uses_period_yyyy_mm() {
        assertEquals("ESI-Return-2026-06.csv", gen.filename(junRun()));
    }

    @Test
    void empty_run_returns_header_only_no_throw() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(junRun()));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of());

        String csv = gen.generate(runId);
        assertEquals(1, csv.split("\r\n").length, "header line only");
    }

    private PayrollRun junRun() {
        PayrollRun r = new PayrollRun();
        r.setId(runId);
        r.setOrgId(orgId);
        r.setPeriodStart(LocalDate.of(2026, 6, 1));
        r.setPeriodEnd(LocalDate.of(2026, 6, 30));
        return r;
    }

    private Employee employee(String esi, String name) {
        Employee e = new Employee();
        e.setId(UUID.randomUUID());
        e.setOrgId(orgId);
        e.setEsiNumber(esi);
        e.setFullName(name);
        e.setEsiApplicable(true);
        return e;
    }

    private Payslip payslip(Employee emp, String gross, String lop) {
        Payslip ps = new Payslip();
        ps.setOrgId(orgId);
        ps.setEmployeeId(emp.getId());
        ps.setEmployee(emp);
        ps.setPayrollRunId(runId);
        ps.setGrossPay(new BigDecimal(gross));
        ps.setLopDays(new BigDecimal(lop));
        ps.setLines(new java.util.ArrayList<>());
        return ps;
    }
}
