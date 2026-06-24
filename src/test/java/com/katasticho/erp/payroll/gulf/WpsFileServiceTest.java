package com.katasticho.erp.payroll.gulf;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.PayrollRun;
import com.katasticho.erp.payroll.entity.Payslip;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.PayrollRunRepository;
import com.katasticho.erp.payroll.repository.PayslipRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class WpsFileServiceTest {

    private final PayrollRunRepository payrollRunRepository = mock(PayrollRunRepository.class);
    private final PayslipRepository payslipRepository = mock(PayslipRepository.class);
    private final EmployeeRepository employeeRepository = mock(EmployeeRepository.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);

    private final Clock clock = Clock.fixed(
            LocalDate.of(2026, 6, 23).atStartOfDay(ZoneId.systemDefault()).toInstant(),
            ZoneId.systemDefault());

    private final WpsFileService svc = new WpsFileService(
            payrollRunRepository, payslipRepository, employeeRepository,
            orgSettingsService, clock);

    private UUID orgId;
    private UUID runId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        runId = UUID.randomUUID();
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private PayrollRun run(LocalDate from, LocalDate to) {
        PayrollRun r = PayrollRun.builder()
                .orgId(orgId)
                .periodStart(from)
                .periodEnd(to)
                .build();
        r.setId(runId);
        return r;
    }

    private Employee employee(String name, String code, String iban, String bankCode) {
        Employee e = Employee.builder()
                .orgId(orgId)
                .fullName(name)
                .employeeCode(code)
                .bankAccountNumber(iban)
                .bankIfsc(bankCode)
                .build();
        e.setId(UUID.randomUUID());
        return e;
    }

    private Payslip payslip(UUID employeeId, BigDecimal netPay) {
        Payslip p = Payslip.builder()
                .orgId(orgId)
                .payrollRunId(runId)
                .employeeId(employeeId)
                .netPay(netPay)
                .build();
        p.setId(UUID.randomUUID());
        return p;
    }

    private void stubSettings(String employerEid, String employerBank, String defaultEmployeeBank) {
        when(orgSettingsService.get(orgId, WpsFileService.SETTING_EMPLOYER_EID, ""))
                .thenReturn(employerEid);
        when(orgSettingsService.get(orgId, WpsFileService.SETTING_EMPLOYER_BANK, ""))
                .thenReturn(employerBank);
        when(orgSettingsService.get(orgId, WpsFileService.SETTING_EMPLOYEE_BANK_DEFAULT, ""))
                .thenReturn(defaultEmployeeBank == null ? "" : defaultEmployeeBank);
    }

    @Test
    void happy_path_two_employees_renders_scr_plus_two_edrs() {
        Employee alice = employee("Alice", "EMP-001", "AE070331234567890123456", "EBI");
        Employee bob = employee("Bob", "EMP-002", "AE140260123456789012345", "EBI");

        when(payrollRunRepository.findById(runId))
                .thenReturn(Optional.of(run(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30))));
        when(payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(
                        payslip(alice.getId(), new BigDecimal("12000.00")),
                        payslip(bob.getId(), new BigDecimal("8000.00"))));
        when(employeeRepository.findById(alice.getId())).thenReturn(Optional.of(alice));
        when(employeeRepository.findById(bob.getId())).thenReturn(Optional.of(bob));
        stubSettings("1234567890123", "EBI", "EBI");

        WpsFileService.WpsFile file = svc.generate(runId);

        assertThat(file.employeeCount()).isEqualTo(2);
        assertThat(file.totalSalary()).isEqualByComparingTo("20000.00");
        assertThat(file.filename()).isEqualTo("WPS-202606-1234567890123.sif");

        String[] lines = file.content().split("\n");
        assertThat(lines[0])
                .startsWith("SCR|1234567890123|EBI|")
                .contains("|202606|00002|20000.00|SIF v2.0|");
        // 30 days in June. Pipes give 11 fields after EDR + employerEID.
        assertThat(lines[1])
                .startsWith("EDR|1234567890123|EMP-001|EBI|AE070331234567890123456|01062026|30062026|30|12000.00|0.00|");
        assertThat(lines[2])
                .contains("|EMP-002|EBI|AE140260123456789012345|01062026|30062026|30|8000.00|0.00|");
    }

    @Test
    void missing_employer_eid_throws() {
        when(payrollRunRepository.findById(runId))
                .thenReturn(Optional.of(run(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30))));
        stubSettings("", "EBI", "EBI");
        when(payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of()); // doesn't matter, EID check fires first

        assertThatThrownBy(() -> svc.generate(runId))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .startsWith("WPS_MISSING_"));
    }

    @Test
    void zero_net_payslips_are_skipped_and_count_is_correct() {
        // Alice on full pay, Bob fully on unpaid leave (zero net).
        Employee alice = employee("Alice", "EMP-001", "AE070331234567890123456", "EBI");
        Employee bob = employee("Bob", "EMP-002", "AE140260123456789012345", "EBI");

        when(payrollRunRepository.findById(runId))
                .thenReturn(Optional.of(run(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30))));
        when(payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(
                        payslip(alice.getId(), new BigDecimal("12000.00")),
                        payslip(bob.getId(), BigDecimal.ZERO)));
        when(employeeRepository.findById(alice.getId())).thenReturn(Optional.of(alice));
        when(employeeRepository.findById(bob.getId())).thenReturn(Optional.of(bob));
        stubSettings("1234567890123", "EBI", "EBI");

        WpsFileService.WpsFile file = svc.generate(runId);
        assertThat(file.employeeCount()).isEqualTo(1);
        assertThat(file.totalSalary()).isEqualByComparingTo("12000.00");
        assertThat(file.content()).contains("|00001|");
    }

    @Test
    void empty_run_throws() {
        when(payrollRunRepository.findById(runId))
                .thenReturn(Optional.of(run(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30))));
        stubSettings("1234567890123", "EBI", "EBI");
        when(payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of());

        assertThatThrownBy(() -> svc.generate(runId))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .isEqualTo("WPS_RUN_EMPTY"));
    }

    @Test
    void employee_without_iban_throws() {
        Employee alice = employee("Alice", "EMP-001", null, "EBI");

        when(payrollRunRepository.findById(runId))
                .thenReturn(Optional.of(run(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30))));
        when(payslipRepository.findByOrgIdAndPayrollRunId(orgId, runId))
                .thenReturn(List.of(payslip(alice.getId(), new BigDecimal("12000"))));
        when(employeeRepository.findById(alice.getId())).thenReturn(Optional.of(alice));
        stubSettings("1234567890123", "EBI", "EBI");

        assertThatThrownBy(() -> svc.generate(runId))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .contains("WPS_MISSING"));
    }
}
