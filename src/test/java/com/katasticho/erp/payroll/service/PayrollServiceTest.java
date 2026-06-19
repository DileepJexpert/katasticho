package com.katasticho.erp.payroll.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.attendance.LeaveRequest;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.payroll.entity.*;
import com.katasticho.erp.payroll.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PayrollServiceTest {

    @Mock private PayrollSettingsRepository settingsRepo;
    @Mock private EmployeeRepository employeeRepo;
    @Mock private SalaryComponentRepository componentRepo;
    @Mock private EmployeeSalaryStructureRepository structureRepo;
    @Mock private PayrollRunRepository runRepo;
    @Mock private PayslipRepository payslipRepo;
    @Mock private PayrollPaymentRepository paymentRepo;
    @Mock private StatutoryPaymentRepository statutoryPaymentRepo;
    @Mock private JournalService journalService;
    @Mock private AccountRepository accountRepo;
    @Mock private com.katasticho.erp.attendance.LeaveRequestRepository leaveRequestRepo;
    @Mock private com.katasticho.erp.payroll.service.ProductionPayrollService productionPayrollService;

    private PayrollService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    private UUID salaryPayableAccountId;
    private UUID pfPayableAccountId;
    private UUID bankAccountId;

    @BeforeEach
    void setUp() {
        service = new PayrollService(
                settingsRepo, employeeRepo, componentRepo, structureRepo,
                runRepo, payslipRepo, paymentRepo, statutoryPaymentRepo,
                journalService, accountRepo, leaveRequestRepo, productionPayrollService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        salaryPayableAccountId = UUID.randomUUID();
        pfPayableAccountId = UUID.randomUUID();
        bankAccountId = UUID.randomUUID();
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private PayrollSettings buildSettings() {
        return PayrollSettings.builder()
                .orgId(orgId)
                .defaultSalaryExpenseAccountId(UUID.randomUUID())
                .defaultSalaryPayableAccountId(salaryPayableAccountId)
                .defaultPfPayableAccountId(pfPayableAccountId)
                .defaultEsiPayableAccountId(UUID.randomUUID())
                .defaultPtPayableAccountId(UUID.randomUUID())
                .defaultLwfPayableAccountId(UUID.randomUUID())
                .defaultTdsPayableAccountId(UUID.randomUUID())
                .pfEnabled(true).esiEnabled(true).ptEnabled(true)
                .lwfEnabled(false).tdsEnabled(false)
                .build();
    }

    private void mockAccountLookup(UUID accountId, String code) {
        Account account = Account.builder().code(code).name(code).type("LIABILITY").build();
        account.setId(accountId);
        account.setOrgId(orgId);
        when(accountRepo.findByOrgIdAndIdAndIsDeletedFalse(orgId, accountId))
                .thenReturn(Optional.of(account));
    }

    // ── Payment recording with journal ──

    @Test
    void recordPayment_postedRun_createsJournal() {
        UUID runId = UUID.randomUUID();
        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("POSTED")
                .periodStart(LocalDate.of(2026, 5, 1))
                .periodEnd(LocalDate.of(2026, 5, 31))
                .netPayTotal(BigDecimal.valueOf(200000))
                .build();

        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        PayrollSettings settings = buildSettings();
        when(settingsRepo.findByOrgId(orgId)).thenReturn(Optional.of(settings));

        mockAccountLookup(salaryPayableAccountId, "SALARY_PAYABLE");
        mockAccountLookup(bankAccountId, "BANK_ACCOUNT");

        JournalEntry journal = JournalEntry.builder()
                .id(UUID.randomUUID()).entryNumber("JE-2026-000099").build();
        when(journalService.postJournal(any())).thenReturn(journal);
        when(paymentRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PayrollPayment payment = PayrollPayment.builder()
                .paymentDate(LocalDate.of(2026, 6, 5))
                .paymentAccountId(bankAccountId)
                .amount(BigDecimal.valueOf(200000))
                .paymentMode("BANK_TRANSFER")
                .build();

        PayrollPayment result = service.recordPayment(runId, payment);

        assertEquals(journal.getId(), result.getJournalEntryId());
        assertEquals(orgId, result.getOrgId());
        assertEquals(runId, result.getPayrollRunId());
        verify(journalService).postJournal(any());
    }

    @Test
    void recordPayment_notPosted_throws() {
        UUID runId = UUID.randomUUID();
        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("APPROVED").build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        PayrollPayment payment = PayrollPayment.builder()
                .paymentDate(LocalDate.now())
                .paymentAccountId(bankAccountId)
                .amount(BigDecimal.valueOf(100000))
                .build();

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordPayment(runId, payment));
        assertEquals("PAYROLL_RUN_NOT_POSTED", ex.getErrorCode());
    }

    // ── Statutory payment with journal ──

    @Test
    void recordStatutoryPayment_pf_createsJournal() {
        PayrollSettings settings = buildSettings();
        when(settingsRepo.findByOrgId(orgId)).thenReturn(Optional.of(settings));

        mockAccountLookup(pfPayableAccountId, "PF_PAYABLE");
        mockAccountLookup(bankAccountId, "BANK_ACCOUNT");

        JournalEntry journal = JournalEntry.builder()
                .id(UUID.randomUUID()).entryNumber("JE-2026-000100").build();
        when(journalService.postJournal(any())).thenReturn(journal);
        when(statutoryPaymentRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        StatutoryPayment payment = StatutoryPayment.builder()
                .statutoryType("PF")
                .periodLabel("May-2026")
                .paymentDate(LocalDate.of(2026, 6, 15))
                .paymentAccountId(bankAccountId)
                .amount(BigDecimal.valueOf(24000))
                .referenceNumber("PF-REF-001")
                .status(null)
                .build();

        StatutoryPayment result = service.recordStatutoryPayment(payment);

        assertEquals(journal.getId(), result.getJournalEntryId());
        assertEquals("PAID", result.getStatus());
        assertEquals(orgId, result.getOrgId());
        verify(journalService).postJournal(any());
    }

    @Test
    void recordStatutoryPayment_unknownType_throws() {
        PayrollSettings settings = buildSettings();
        when(settingsRepo.findByOrgId(orgId)).thenReturn(Optional.of(settings));

        StatutoryPayment payment = StatutoryPayment.builder()
                .statutoryType("UNKNOWN")
                .paymentDate(LocalDate.now())
                .paymentAccountId(bankAccountId)
                .amount(BigDecimal.valueOf(1000))
                .build();

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.recordStatutoryPayment(payment));
        assertEquals("PAYROLL_UNKNOWN_STATUTORY_TYPE", ex.getErrorCode());
    }

    // ── Payroll run lifecycle ──

    @Test
    void approveRun_calculated_succeeds() {
        UUID runId = UUID.randomUUID();
        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("CALCULATED")
                .periodStart(LocalDate.of(2026, 5, 1))
                .periodEnd(LocalDate.of(2026, 5, 31))
                .build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));
        when(runRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PayrollRun result = service.approveRun(runId);

        assertEquals("APPROVED", result.getStatus());
        assertEquals(userId, result.getApprovedBy());
        assertNotNull(result.getApprovedAt());
    }

    @Test
    void approveRun_notCalculated_throws() {
        UUID runId = UUID.randomUUID();
        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("DRAFT").build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.approveRun(runId));
        assertEquals("PAYROLL_RUN_NOT_CALCULATED", ex.getErrorCode());
    }

    @Test
    void cancelRun_posted_throws() {
        UUID runId = UUID.randomUUID();
        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("POSTED").build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.cancelRun(runId));
        assertEquals("PAYROLL_RUN_POSTED_CANNOT_CANCEL", ex.getErrorCode());
    }

    @Test
    void cancelRun_draft_succeeds() {
        UUID runId = UUID.randomUUID();
        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("DRAFT").build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));
        when(runRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of());

        PayrollRun result = service.cancelRun(runId);

        assertEquals("CANCELLED", result.getStatus());
    }

    // ── Attendance LOP proration (V71 attendance -> payroll) ──

    /** Builds the calculateRun mock chain for one ACTIVE employee on a single
     *  fixed BASIC earning, with all statutory deductions disabled so
     *  gross == net and only LOP proration moves the number. */
    private Payslip runPayrollWithLeave(int basic, LocalDate periodStart,
                                        LocalDate periodEnd, List<LeaveRequest> leaves) {
        UUID runId = UUID.randomUUID();
        UUID empId = UUID.randomUUID();

        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("DRAFT")
                .periodStart(periodStart).periodEnd(periodEnd)
                .build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        // Statutory all off -> gross == net, isolates the LOP factor
        PayrollSettings settings = PayrollSettings.builder()
                .orgId(orgId).payFrequency("MONTHLY")
                .pfEnabled(false).esiEnabled(false).ptEnabled(false)
                .lwfEnabled(false).tdsEnabled(false)
                .build();
        when(settingsRepo.findByOrgId(orgId)).thenReturn(Optional.of(settings));

        Employee emp = Employee.builder()
                .id(empId).orgId(orgId).userId(userId)
                .employeeCode("E1").employmentStatus("ACTIVE")
                .build();
        when(employeeRepo.findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE"))
                .thenReturn(List.of(emp));
        when(componentRepo.findByOrgIdAndActiveTrueOrderByCodeAsc(orgId)).thenReturn(List.of());
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of());

        SalaryComponent basicComp = SalaryComponent.builder()
                .code("BASIC").name("Basic Salary").componentType("EARNING").build();
        EmployeeSalaryComponent line = EmployeeSalaryComponent.builder()
                .salaryComponent(basicComp)
                .calculationType("FIXED")
                .amount(BigDecimal.valueOf(basic))
                .build();
        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .orgId(orgId).employeeId(empId).status("ACTIVE")
                .lines(new ArrayList<>(List.of(line)))
                .build();
        when(structureRepo.findCurrentActive(orgId, empId)).thenReturn(Optional.of(structure));

        when(leaveRequestRepo
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, userId, List.of("APPROVED"), periodEnd, periodStart))
                .thenReturn(leaves);

        ArgumentCaptor<Payslip> captor = ArgumentCaptor.forClass(Payslip.class);
        when(payslipRepo.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));
        when(runRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.calculateRun(runId);
        return captor.getValue();
    }

    @Test
    void calculateRun_unpaidLeave_proratesEarningsAndRecordsLop() {
        LocalDate start = LocalDate.of(2026, 6, 1);
        LocalDate end = LocalDate.of(2026, 6, 30); // 30 period days
        LeaveRequest unpaid = LeaveRequest.builder()
                .orgId(orgId).userId(userId).status("APPROVED").leaveType("UNPAID")
                .fromDate(LocalDate.of(2026, 6, 1)).toDate(LocalDate.of(2026, 6, 3)) // 3 LOP days
                .build();

        Payslip slip = runPayrollWithLeave(30000, start, end, List.of(unpaid));

        // 30000 * (30 - 3)/30 = 30000 * 0.9
        assertEquals(0, slip.getGrossPay().compareTo(new BigDecimal("27000.00")));
        assertEquals(0, slip.getLopDays().compareTo(new BigDecimal("3")));
        assertEquals(0, slip.getNetPay().compareTo(new BigDecimal("27000.00")));
    }

    @Test
    void calculateRun_leaveClippedToPeriod_countsOnlyInPeriodDays() {
        LocalDate start = LocalDate.of(2026, 6, 1);
        LocalDate end = LocalDate.of(2026, 6, 30);
        // Leave spans May 30 -> Jun 2; only Jun 1-2 (2 days) fall in the run period
        LeaveRequest spanning = LeaveRequest.builder()
                .orgId(orgId).userId(userId).status("APPROVED").leaveType("UNPAID")
                .fromDate(LocalDate.of(2026, 5, 30)).toDate(LocalDate.of(2026, 6, 2))
                .build();

        Payslip slip = runPayrollWithLeave(30000, start, end, List.of(spanning));

        assertEquals(0, slip.getLopDays().compareTo(new BigDecimal("2")));
        // 30000 * (30 - 2)/30, lopFactor at scale 6 = 0.933333 -> 27999.99
        assertEquals(0, slip.getGrossPay().compareTo(new BigDecimal("27999.99")));
    }

    @Test
    void calculateRun_paidLeaveOnly_noLopFullPay() {
        LocalDate start = LocalDate.of(2026, 6, 1);
        LocalDate end = LocalDate.of(2026, 6, 30);
        // CASUAL (paid) leave must NOT reduce pay
        LeaveRequest paid = LeaveRequest.builder()
                .orgId(orgId).userId(userId).status("APPROVED").leaveType("CASUAL")
                .fromDate(LocalDate.of(2026, 6, 5)).toDate(LocalDate.of(2026, 6, 7))
                .build();

        Payslip slip = runPayrollWithLeave(30000, start, end, List.of(paid));

        assertEquals(0, slip.getLopDays().compareTo(BigDecimal.ZERO));
        assertEquals(0, slip.getGrossPay().compareTo(new BigDecimal("30000")));
    }

    // ─── V18: Employee profile depth ───

    @Test
    void updateEmployee_copiesDepthFields() {
        UUID id = UUID.randomUUID();
        Employee existing = Employee.builder()
                .id(id).orgId(orgId).fullName("Old name")
                .employmentStatus("ACTIVE").isDeleted(false)
                .build();
        when(employeeRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(existing));
        when(employeeRepo.save(any(Employee.class))).thenAnswer(inv -> inv.getArgument(0));

        UUID photoId = UUID.randomUUID();
        Employee updates = Employee.builder()
                .fullName("New name")
                .dateOfBirth(LocalDate.of(1990, 5, 12))
                .gender("FEMALE")
                .maritalStatus("MARRIED")
                .bloodGroup("O+")
                .nationality("Indian")
                .personalEmail("priya@example.com")
                .currentAddressLine1("12 MG Road")
                .currentCity("Bengaluru")
                .currentState("Karnataka")
                .currentPincode("560001")
                .permanentAddressLine1("Village Road")
                .permanentCity("Mysuru")
                .permanentState("Karnataka")
                .permanentPincode("570001")
                .emergencyContactName("Ravi")
                .emergencyContactRelationship("Spouse")
                .emergencyContactPhone("9876543210")
                .employmentType("FULL_TIME")
                .workLocation("HQ — Bengaluru")
                .probationEndDate(LocalDate.of(2026, 12, 1))
                .confirmationDate(LocalDate.of(2026, 12, 2))
                .noticePeriodDays(60)
                .photoAttachmentId(photoId)
                .build();

        Employee saved = service.updateEmployee(id, updates);

        assertEquals("New name", saved.getFullName());
        assertEquals(LocalDate.of(1990, 5, 12), saved.getDateOfBirth());
        assertEquals("FEMALE", saved.getGender());
        assertEquals("MARRIED", saved.getMaritalStatus());
        assertEquals("O+", saved.getBloodGroup());
        assertEquals("Indian", saved.getNationality());
        assertEquals("priya@example.com", saved.getPersonalEmail());
        assertEquals("12 MG Road", saved.getCurrentAddressLine1());
        assertEquals("Bengaluru", saved.getCurrentCity());
        assertEquals("Karnataka", saved.getCurrentState());
        assertEquals("560001", saved.getCurrentPincode());
        assertEquals("Village Road", saved.getPermanentAddressLine1());
        assertEquals("Mysuru", saved.getPermanentCity());
        assertEquals("570001", saved.getPermanentPincode());
        assertEquals("Ravi", saved.getEmergencyContactName());
        assertEquals("Spouse", saved.getEmergencyContactRelationship());
        assertEquals("9876543210", saved.getEmergencyContactPhone());
        assertEquals("FULL_TIME", saved.getEmploymentType());
        assertEquals("HQ — Bengaluru", saved.getWorkLocation());
        assertEquals(LocalDate.of(2026, 12, 1), saved.getProbationEndDate());
        assertEquals(LocalDate.of(2026, 12, 2), saved.getConfirmationDate());
        assertEquals(60, saved.getNoticePeriodDays());
        assertEquals(photoId, saved.getPhotoAttachmentId());
    }

    @Test
    void createEmployee_persistsDepthFields() {
        when(employeeRepo.save(any(Employee.class))).thenAnswer(inv -> inv.getArgument(0));

        Employee input = Employee.builder()
                .fullName("Anita")
                .dateOfBirth(LocalDate.of(1995, 1, 1))
                .gender("FEMALE")
                .employmentType("CONTRACT")
                .currentCity("Pune")
                .build();

        Employee created = service.createEmployee(input);

        ArgumentCaptor<Employee> captor = ArgumentCaptor.forClass(Employee.class);
        verify(employeeRepo).save(captor.capture());
        Employee persisted = captor.getValue();

        assertEquals(orgId, persisted.getOrgId());
        assertEquals("ACTIVE", persisted.getEmploymentStatus());
        assertEquals(LocalDate.of(1995, 1, 1), persisted.getDateOfBirth());
        assertEquals("FEMALE", persisted.getGender());
        assertEquals("CONTRACT", persisted.getEmploymentType());
        assertEquals("Pune", persisted.getCurrentCity());
        assertSame(persisted, created);
    }
}
