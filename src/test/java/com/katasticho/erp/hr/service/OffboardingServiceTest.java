package com.katasticho.erp.hr.service;

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
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OffboardingServiceTest {

    @Mock private OffboardingRepository offboardingRepo;
    @Mock private OffboardingTaskRepository taskRepo;
    @Mock private EmployeeRepository employeeRepo;
    @Mock private CountryAccessService countryAccess;
    @Mock private GulfPayrollService gulfPayrollService;
    @Mock private com.katasticho.erp.payroll.india.IndiaGratuityService indiaGratuityService;
    @Mock private JournalService journalService;
    @Mock private AccountRepository accountRepo;
    @Mock private OrgSettingsService orgSettingsService;
    private final Clock clock = Clock.fixed(
            LocalDate.of(2026, 6, 24).atStartOfDay(ZoneId.systemDefault()).toInstant(),
            ZoneId.systemDefault());

    private OffboardingService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID empUserId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new OffboardingService(offboardingRepo, taskRepo, employeeRepo,
                countryAccess, gulfPayrollService, indiaGratuityService, journalService,
                accountRepo, orgSettingsService, clock);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void initiate_seedsClearanceChecklist() {
        when(offboardingRepo.save(any())).thenAnswer(i -> {
            Offboarding o = i.getArgument(0);
            if (o.getId() == null) o.setId(UUID.randomUUID());
            return o;
        });
        when(taskRepo.save(any())).thenAnswer(i -> i.getArgument(0));
        when(taskRepo.findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(eq(orgId), any()))
                .thenReturn(List.of());

        service.initiate(empUserId, LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31), "New role");

        // 5 default clearance tasks seeded
        verify(taskRepo, times(5)).save(any());
    }

    @Test
    void complete_withPendingTasks_throws() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(ob));
        when(taskRepo.findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(orgId, id))
                .thenReturn(List.of(
                        OffboardingTask.builder().completed(true).build(),
                        OffboardingTask.builder().completed(false).build()));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.complete(id));
        assertEquals("OFFB_TASKS_PENDING", ex.getErrorCode());
    }

    @Test
    void complete_allTasksDone_marksEmployeeExited() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").lastWorkingDay(LocalDate.of(2026, 5, 31)).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(ob));
        when(taskRepo.findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(orgId, id))
                .thenReturn(List.of(
                        OffboardingTask.builder().completed(true).build(),
                        OffboardingTask.builder().completed(true).build()));
        when(offboardingRepo.save(any())).thenAnswer(i -> i.getArgument(0));
        Employee emp = Employee.builder().userId(empUserId).employmentStatus("ACTIVE").build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.of(emp));
        when(employeeRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Offboarding result = service.complete(id);

        assertEquals("COMPLETED", result.getStatus());
        ArgumentCaptor<Employee> cap = ArgumentCaptor.forClass(Employee.class);
        verify(employeeRepo).save(cap.capture());
        assertEquals("EXITED", cap.getValue().getEmploymentStatus());
        assertEquals(LocalDate.of(2026, 5, 31), cap.getValue().getDateOfExit());
    }

    // ── Gulf gratuity payout (V16) ──

    private Account stubAccount(String code) {
        Account a = Account.builder().code(code).name(code).type("LIABILITY").build();
        a.setId(UUID.randomUUID());
        a.setOrgId(orgId);
        when(accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code))
                .thenReturn(Optional.of(a));
        return a;
    }

    @Test
    void payGratuity_uaeOrg_postsJournalAndStampsFields() {
        UUID id = UUID.randomUUID();
        UUID empPayrollId = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").lastWorkingDay(LocalDate.of(2026, 6, 30)).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("AE");
        Employee emp = Employee.builder().id(empPayrollId).userId(empUserId)
                .employeeCode("E007").employmentStatus("ACTIVE")
                .dateOfJoining(LocalDate.of(2022, 1, 1)).build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.of(emp));
        when(gulfPayrollService.computeFor(empPayrollId, LocalDate.of(2026, 6, 30)))
                .thenReturn(new GratuityResult("AE",
                        new BigDecimal("4.5"), new BigDecimal("333.3333"),
                        new BigDecimal("94.50"), new BigDecimal("31500.00"),
                        new BigDecimal("31500.00"), "UAE formula"));
        when(orgSettingsService.get(eq(orgId), eq("payroll.gratuity_payment_account_code"), eq("")))
                .thenReturn("");
        stubAccount("2050");
        stubAccount("1010");
        JournalEntry je = JournalEntry.builder().entryNumber("JE-2026-000200").build();
        je.setId(UUID.randomUUID());
        when(journalService.postJournal(any())).thenReturn(je);
        when(offboardingRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Offboarding result = service.payGratuity(id, null);

        assertEquals(0, result.getGratuityAmount().compareTo(new BigDecimal("31500.00")));
        assertEquals(je.getId(), result.getGratuityJournalEntryId());
        assertNotNull(result.getGratuityPaidAt());
        verify(journalService).postJournal(any());
    }

    @Test
    void payGratuity_indiaOrg_postsPayoutAgainstProvision2080() {
        UUID id = UUID.randomUUID();
        UUID empPayrollId = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").lastWorkingDay(LocalDate.of(2026, 6, 30)).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("IN");
        Employee emp = Employee.builder().id(empPayrollId).userId(empUserId)
                .employeeCode("E010").employmentStatus("ACTIVE")
                .dateOfJoining(LocalDate.of(2019, 1, 1)).build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.of(emp));
        // eligible, capped payout ₹75,000
        when(indiaGratuityService.computeFor(empPayrollId, LocalDate.of(2026, 6, 30)))
                .thenReturn(new com.katasticho.erp.payroll.india.IndiaGratuityResult(
                        new BigDecimal("7.500"), 8, true, new BigDecimal("26000"),
                        new BigDecimal("120000.00"), new BigDecimal("120000.00"), "India formula"));
        when(orgSettingsService.get(eq(orgId), eq("payroll.gratuity_payment_account_code"), eq("")))
                .thenReturn("");
        stubAccount("2080");
        stubAccount("1010");
        JournalEntry je = JournalEntry.builder().entryNumber("JE-2026-000300").build();
        je.setId(UUID.randomUUID());
        ArgumentCaptor<com.katasticho.erp.accounting.dto.JournalPostRequest> captor =
                ArgumentCaptor.forClass(com.katasticho.erp.accounting.dto.JournalPostRequest.class);
        when(journalService.postJournal(any())).thenReturn(je);
        when(offboardingRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Offboarding result = service.payGratuity(id, null);

        assertEquals(0, result.getGratuityAmount().compareTo(new BigDecimal("120000.00")));
        assertEquals(je.getId(), result.getGratuityJournalEntryId());
        verify(journalService).postJournal(captor.capture());
        assertEquals("2080", captor.getValue().lines().get(0).accountCode());
        assertEquals(0, captor.getValue().lines().get(0).debit().compareTo(new BigDecimal("120000.00")));
    }

    @Test
    void payGratuity_unsupportedCountry_throwsNotApplicable() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("KE");

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.payGratuity(id, null));
        assertEquals("OFFB_GRATUITY_NOT_APPLICABLE", ex.getErrorCode());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void payGratuity_secondCall_refusesAsAlreadyPaid() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").gratuityJournalEntryId(UUID.randomUUID()).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("AE");

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.payGratuity(id, null));
        assertEquals("OFFB_GRATUITY_ALREADY_PAID", ex.getErrorCode());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void payGratuity_noEmployeeLink_throws() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("OM");
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.payGratuity(id, null));
        assertEquals("OFFB_GRATUITY_NO_EMPLOYEE", ex.getErrorCode());
    }

    @Test
    void payGratuity_underOneYear_recordsNilWithoutJournal() {
        UUID id = UUID.randomUUID();
        UUID empPayrollId = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").lastWorkingDay(LocalDate.of(2026, 6, 1)).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("AE");
        Employee emp = Employee.builder().id(empPayrollId).userId(empUserId)
                .dateOfJoining(LocalDate.of(2025, 9, 1)).build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.of(emp));
        // Under-1-year forfeit returns nil capped gratuity.
        when(gulfPayrollService.computeFor(empPayrollId, LocalDate.of(2026, 6, 1)))
                .thenReturn(new GratuityResult("AE", new BigDecimal("0.75"),
                        new BigDecimal("333.33"), BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, "Under 1 year"));
        when(offboardingRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Offboarding result = service.payGratuity(id, null);

        assertEquals(0, result.getGratuityAmount().compareTo(BigDecimal.ZERO));
        assertNull(result.getGratuityJournalEntryId());
        assertNotNull(result.getGratuityPaidAt());
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void payGratuity_overrideAccountCode_usesOverride() {
        UUID id = UUID.randomUUID();
        UUID empPayrollId = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").lastWorkingDay(LocalDate.of(2026, 6, 30)).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(ob));
        when(countryAccess.countryOf(orgId)).thenReturn("AE");
        Employee emp = Employee.builder().id(empPayrollId).userId(empUserId)
                .dateOfJoining(LocalDate.of(2020, 1, 1)).build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.of(emp));
        when(gulfPayrollService.computeFor(empPayrollId, LocalDate.of(2026, 6, 30)))
                .thenReturn(new GratuityResult("AE", new BigDecimal("6.5"),
                        new BigDecimal("333.3333"), new BigDecimal("150"),
                        new BigDecimal("50000"), new BigDecimal("50000"), "UAE formula"));
        stubAccount("2050");
        stubAccount("1020");
        JournalEntry je = JournalEntry.builder().entryNumber("JE-2026-000300").build();
        je.setId(UUID.randomUUID());
        when(journalService.postJournal(any())).thenReturn(je);
        when(offboardingRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        // Caller supplies bank account directly — org setting should be ignored.
        service.payGratuity(id, "1020");

        verify(orgSettingsService, never()).get(any(), any(), any());
        verify(accountRepo).findByOrgIdAndCodeAndIsDeletedFalse(orgId, "1020");
    }
}
