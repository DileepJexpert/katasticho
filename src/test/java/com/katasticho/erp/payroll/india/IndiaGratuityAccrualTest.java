package com.katasticho.erp.payroll.india;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.entity.EmployeeSalaryComponent;
import com.katasticho.erp.payroll.entity.EmployeeSalaryStructure;
import com.katasticho.erp.payroll.entity.SalaryComponent;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import com.katasticho.erp.payroll.repository.EmployeeSalaryStructureRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class IndiaGratuityAccrualTest {

    @Mock private EmployeeRepository employeeRepository;
    @Mock private EmployeeSalaryStructureRepository salaryStructureRepository;
    @Mock private AccountRepository accountRepository;
    @Mock private JournalService journalService;
    @Mock private OrgSettingsService orgSettingsService;
    @Mock private IndiaGratuityAccrualRepository accrualRepository;

    private IndiaGratuityService svc;

    private final UUID orgId = UUID.randomUUID();
    private final UUID empId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(
                LocalDate.of(2026, 7, 2).atStartOfDay(ZoneId.systemDefault()).toInstant(),
                ZoneId.systemDefault());
        svc = new IndiaGratuityService(employeeRepository, salaryStructureRepository,
                accountRepository, journalService, orgSettingsService, accrualRepository, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());

        when(orgSettingsService.get(orgId, "payroll.india_gratuity_enabled", "false")).thenReturn("true");
        when(orgSettingsService.get(orgId, "payroll.india_gratuity_accrue_from_joining", "true"))
                .thenReturn("true");
        when(accrualRepository.findByOrgIdAndPeriodYearAndPeriodMonthAndIsDeletedFalse(any(), anyInt(), anyInt()))
                .thenReturn(Optional.empty());
        when(accrualRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        Employee emp = Employee.builder()
                .employeeCode("EMP-1").fullName("Ravi Kumar")
                .dateOfJoining(LocalDate.of(2020, 1, 1))
                .employmentStatus("ACTIVE").build();
        emp.setId(empId);
        emp.setOrgId(orgId);
        when(employeeRepository.findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE"))
                .thenReturn(List.of(emp));

        SalaryComponent basic = SalaryComponent.builder().code("BASIC").build();
        EmployeeSalaryComponent basicLine = EmployeeSalaryComponent.builder()
                .salaryComponent(basic).amount(new BigDecimal("26000")).build();
        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .effectiveFrom(LocalDate.of(2020, 1, 1))
                .grossMonthly(new BigDecimal("40000"))
                .lines(new java.util.ArrayList<>(List.of(basicLine)))
                .build();
        when(salaryStructureRepository
                .findByOrgIdAndEmployeeIdAndStatusOrderByEffectiveFromDesc(orgId, empId, "ACTIVE"))
                .thenReturn(List.of(structure));

        when(accountRepository.findByOrgIdAndCodeAndIsDeletedFalse(eq(orgId), anyString()))
                .thenReturn(Optional.of(mock(Account.class)));
        JournalEntry entry = mock(JournalEntry.class);
        when(entry.getId()).thenReturn(UUID.randomUUID());
        when(journalService.postJournal(any())).thenReturn(entry);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private static int anyInt() {
        return org.mockito.ArgumentMatchers.anyInt();
    }

    @Test
    void postAccrual_posts_expense_debit_and_provision_credit() {
        Map<String, Object> result = svc.postAccrual(2026, 6);

        // 26000 × 15/26 / 12 = 1250.00
        assertThat(result.get("totalAmount")).isEqualTo(new BigDecimal("1250.00"));
        assertThat(result.get("employeeCount")).isEqualTo(1);
        assertThat(result.get("posted")).isEqualTo(true);

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(captor.capture());
        var lines = captor.getValue().lines();
        assertThat(lines).hasSize(2);
        assertThat(lines.get(0).accountCode()).isEqualTo("5130");
        assertThat(lines.get(0).debit()).isEqualByComparingTo("1250.00");
        assertThat(lines.get(1).accountCode()).isEqualTo("2080");
        assertThat(lines.get(1).credit()).isEqualByComparingTo("1250.00");
        verify(accrualRepository).save(any());
    }

    @Test
    void postAccrual_is_disabled_until_the_org_opts_in() {
        when(orgSettingsService.get(orgId, "payroll.india_gratuity_enabled", "false")).thenReturn("false");

        assertThatThrownBy(() -> svc.postAccrual(2026, 6))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "GRATUITY_DISABLED");
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void postAccrual_is_idempotent_per_period() {
        IndiaGratuityAccrual prior = IndiaGratuityAccrual.builder()
                .periodYear(2026).periodMonth(6)
                .totalAmount(new BigDecimal("1250.00")).employeeCount(1)
                .journalEntryId(UUID.randomUUID()).build();
        when(accrualRepository.findByOrgIdAndPeriodYearAndPeriodMonthAndIsDeletedFalse(orgId, 2026, 6))
                .thenReturn(Optional.of(prior));

        assertThatThrownBy(() -> svc.postAccrual(2026, 6))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "GRATUITY_ALREADY_ACCRUED");
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void previewAccrual_lists_employees_without_posting() {
        Map<String, Object> result = svc.previewAccrual(2026, 6);

        assertThat(result.get("employeeCount")).isEqualTo(1);
        assertThat(result.get("totalAmount")).isEqualTo(new BigDecimal("1250.00"));
        assertThat(result).doesNotContainKey("posted");
        verify(journalService, never()).postJournal(any());
        verify(accrualRepository, never()).save(any());
    }
}
