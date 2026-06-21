package com.katasticho.erp.payroll.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
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
class BankSalaryFileGeneratorTest {

    @Mock private PayrollRunRepository runRepo;
    @Mock private PayslipRepository payslipRepo;
    @Mock private EmployeeRepository employeeRepo;

    private BankSalaryFileGenerator gen;
    private final UUID orgId = UUID.randomUUID();
    private final UUID runId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        gen = new BankSalaryFileGenerator(runRepo, payslipRepo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    @Test
    void hdfc_format_renders_correct_columns_and_reference() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee emp = employee("EMP-001", "Ramesh Kumar", "1234567890", "HDFC0001234");
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(emp, "40800")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.HDFC);
        String[] lines = csv.split("\r\n");
        assertEquals("Beneficiary Account Number,Beneficiary Name,IFSC Code,Amount,Reference,Email,Mobile",
                lines[0]);
        String[] cols = lines[1].split(",", -1);
        assertEquals("1234567890", cols[0]);
        assertEquals("Ramesh Kumar", cols[1]);
        assertEquals("HDFC0001234", cols[2]);
        assertEquals("40800.00", cols[3]);
        assertEquals("SAL-062026-EMP-001", cols[4]);
    }

    @Test
    void icici_format_columns_order() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee emp = employee("EMP-002", "Sita Devi", "9876543210", "ICIC0009876");
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(emp, "32000")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.ICICI);
        String[] cols = csv.split("\r\n")[1].split(",", -1);
        assertEquals("N", cols[0]);
        assertEquals("EMP-002", cols[1]);
        assertEquals("Sita Devi", cols[2]);
        assertEquals("9876543210", cols[3]);
        assertEquals("ICIC0009876", cols[4]);
        assertEquals("32000.00", cols[5]);
        assertEquals("SAL-062026-EMP-002", cols[6]);
    }

    @Test
    void generic_format_works_with_all_columns() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee emp = employee("EMP-003", "Anjali", "1111222233", "SBIN0001111");
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(emp, "25000")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.GENERIC);
        String[] cols = csv.split("\r\n")[1].split(",", -1);
        assertEquals("EMP-003", cols[0]);   // Sr / employeeCode
        assertEquals("EMP-003", cols[1]);   // Employee Code
        assertEquals("Anjali", cols[2]);    // Beneficiary Name
        assertEquals("1111222233", cols[3]);
        assertEquals("SBIN0001111", cols[4]);
        assertEquals("25000.00", cols[5]);
        assertEquals("BANK", cols[6]);
        assertTrue(cols[7].startsWith("SAL-"));
    }

    @Test
    void rejects_unapproved_run() {
        PayrollRun run = new PayrollRun();
        run.setId(runId);
        run.setOrgId(orgId);
        run.setStatus("DRAFT");
        when(runRepo.findById(runId)).thenReturn(Optional.of(run));

        var ex = assertThrows(BusinessException.class,
                () -> gen.generate(runId, BankSalaryFileGenerator.BankFormat.GENERIC));
        assertEquals("PAYROLL_BANK_FILE_NOT_APPROVED", ex.getErrorCode());
    }

    @Test
    void skips_employees_without_bank_account() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee withBank = employee("EMP-001", "WithBank", "1234567890", "HDFC0001234");
        Employee noBank = employee("EMP-002", "NoBank", null, null);
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(withBank, "30000"), payslip(noBank, "30000")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.GENERIC);
        // header + 1 data row only
        assertEquals(2, csv.split("\r\n").length);
        assertTrue(csv.contains("WithBank"));
        assertFalse(csv.contains("NoBank"));
    }

    @Test
    void skips_cash_or_cheque_payment_mode() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee cash = employee("EMP-001", "CashPaid", "1234567890", "HDFC0001234");
        cash.setPaymentMode("CASH");
        Employee bank = employee("EMP-002", "BankPaid", "9999999999", "HDFC0009999");
        bank.setPaymentMode("BANK_TRANSFER");
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(cash, "30000"), payslip(bank, "30000")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.GENERIC);
        assertEquals(2, csv.split("\r\n").length);
        assertTrue(csv.contains("BankPaid"));
        assertFalse(csv.contains("CashPaid"));
    }

    @Test
    void skips_zero_or_negative_net_pay() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee emp = employee("EMP-001", "Zero", "1234567890", "HDFC0001234");
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(emp, "0")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.GENERIC);
        assertEquals(1, csv.split("\r\n").length, "header only");
    }

    @Test
    void name_with_comma_is_quoted() {
        when(runRepo.findById(runId)).thenReturn(Optional.of(postedRun()));
        Employee emp = employee("EMP-001", "Doe, John", "1234567890", "HDFC0001234");
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(emp, "30000")));

        String csv = gen.generate(runId, BankSalaryFileGenerator.BankFormat.GENERIC);
        assertTrue(csv.contains("\"Doe, John\""));
    }

    @Test
    void filename_includes_format_and_period() {
        PayrollRun run = postedRun();
        assertEquals("Salary-HDFC-2026-06.csv",
                gen.filename(run, BankSalaryFileGenerator.BankFormat.HDFC));
        assertEquals("Salary-GENERIC-2026-06.csv",
                gen.filename(run, BankSalaryFileGenerator.BankFormat.GENERIC));
    }

    // ── helpers ───────────────────────────────────────────────────

    private PayrollRun postedRun() {
        PayrollRun r = new PayrollRun();
        r.setId(runId);
        r.setOrgId(orgId);
        r.setPeriodStart(LocalDate.of(2026, 6, 1));
        r.setPeriodEnd(LocalDate.of(2026, 6, 30));
        r.setStatus("POSTED");
        return r;
    }

    private Employee employee(String code, String name, String account, String ifsc) {
        Employee e = new Employee();
        e.setId(UUID.randomUUID());
        e.setOrgId(orgId);
        e.setEmployeeCode(code);
        e.setFullName(name);
        e.setBankAccountNumber(account);
        e.setBankIfsc(ifsc);
        return e;
    }

    private Payslip payslip(Employee emp, String net) {
        Payslip ps = new Payslip();
        ps.setOrgId(orgId);
        ps.setEmployeeId(emp.getId());
        ps.setEmployee(emp);
        ps.setPayrollRunId(runId);
        ps.setNetPay(new BigDecimal(net));
        return ps;
    }
}
