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
    @Mock private com.katasticho.erp.payroll.service.ProfessionalTaxCalculator ptCalculator;
    @Mock private com.katasticho.erp.payroll.service.LabourWelfareFundCalculator lwfCalculator;
    @Mock private com.katasticho.erp.common.country.CountryAccessService countryAccess;
    @Mock private com.katasticho.erp.payroll.gulf.GulfPayrollService gulfPayrollService;

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
                journalService, accountRepo, leaveRequestRepo, productionPayrollService,
                ptCalculator, lwfCalculator, countryAccess, gulfPayrollService);
        // Default: India org so existing statutory assertions hold.
        org.mockito.Mockito.lenient().when(countryAccess.isCountry("IN")).thenReturn(true);
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

    // ─── Country-gated statutory deductions (UAE skips PF/ESI/PT/LWF) ───

    private static SalaryComponent comp(String code, String type) {
        return SalaryComponent.builder().code(code).name(code).componentType(type).build();
    }

    /** Builds a calculateRun mock chain with all four India statutory settings
     *  enabled, so an India run produces PF/ESI/PT/LWF lines and a UAE run
     *  must NOT. Returns the captured Payslip. */
    private Payslip runPayrollAllStatutoryEnabled(int basic) {
        UUID runId = UUID.randomUUID();
        UUID empId = UUID.randomUUID();
        LocalDate start = LocalDate.of(2026, 6, 1);
        LocalDate end = LocalDate.of(2026, 6, 30);

        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("DRAFT")
                .periodStart(start).periodEnd(end).build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        PayrollSettings settings = PayrollSettings.builder()
                .orgId(orgId).payFrequency("MONTHLY")
                .pfEnabled(true).esiEnabled(true).ptEnabled(true)
                .lwfEnabled(true).tdsEnabled(false).build();
        when(settingsRepo.findByOrgId(orgId)).thenReturn(Optional.of(settings));

        Employee emp = Employee.builder()
                .id(empId).orgId(orgId).userId(userId)
                .employeeCode("E1").employmentStatus("ACTIVE")
                .pfApplicable(true).esiApplicable(true)
                .ptApplicable(true).lwfApplicable(true)
                .build();
        when(employeeRepo.findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE"))
                .thenReturn(List.of(emp));

        // Seed the org's statutory components so calculatePayslip's addStatutoryLine
        // can resolve PF/ESI/PT/LWF by code (it skips with a warn if absent).
        SalaryComponent basicComp = comp("BASIC", "EARNING");
        SalaryComponent pfEmpComp = comp("PF_EMPLOYEE", "DEDUCTION");
        SalaryComponent pfErComp = comp("PF_EMPLOYER", "EMPLOYER_CONTRIBUTION");
        SalaryComponent esiEmpComp = comp("ESI_EMPLOYEE", "DEDUCTION");
        SalaryComponent esiErComp = comp("ESI_EMPLOYER", "EMPLOYER_CONTRIBUTION");
        SalaryComponent ptComp = comp("PT", "DEDUCTION");
        SalaryComponent lwfComp = comp("LWF", "DEDUCTION");
        when(componentRepo.findByOrgIdAndActiveTrueOrderByCodeAsc(orgId)).thenReturn(
                List.of(basicComp, pfEmpComp, pfErComp, esiEmpComp, esiErComp, ptComp, lwfComp));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of());

        EmployeeSalaryComponent line = EmployeeSalaryComponent.builder()
                .salaryComponent(basicComp).calculationType("FIXED")
                .amount(BigDecimal.valueOf(basic)).build();
        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .orgId(orgId).employeeId(empId).status("ACTIVE")
                .lines(new ArrayList<>(List.of(line))).build();
        when(structureRepo.findCurrentActive(orgId, empId)).thenReturn(Optional.of(structure));

        when(leaveRequestRepo
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, userId, List.of("APPROVED"), end, start))
                .thenReturn(List.of());

        // PT/LWF calculators return non-zero so an India run actually deducts.
        org.mockito.Mockito.lenient().when(ptCalculator.calculate(
                eq(orgId), any(Employee.class), any(BigDecimal.class), any(LocalDate.class)))
                .thenReturn(new BigDecimal("200"));
        org.mockito.Mockito.lenient().when(lwfCalculator.calculate(
                eq(orgId), any(BigDecimal.class), any(LocalDate.class)))
                .thenReturn(new LabourWelfareFundCalculator.Contribution(
                        new BigDecimal("25"), new BigDecimal("75")));

        ArgumentCaptor<Payslip> captor = ArgumentCaptor.forClass(Payslip.class);
        when(payslipRepo.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));
        when(runRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.calculateRun(runId);
        return captor.getValue();
    }

    @Test
    void calculateRun_indiaOrg_deductsAllFourStatutory() {
        // Default setUp() returns isCountry("IN") = true.
        Payslip slip = runPayrollAllStatutoryEnabled(20000);
        java.util.Set<String> codes = slip.getLines().stream()
                .map(l -> l.getSalaryComponent().getCode())
                .collect(java.util.stream.Collectors.toSet());
        assertEquals(true, codes.contains("PF_EMPLOYEE"));
        assertEquals(true, codes.contains("ESI_EMPLOYEE"));
        assertEquals(true, codes.contains("PT"));
        assertEquals(true, codes.contains("LWF"));
    }

    /**
     * V15 gulf gratuity accrual — fixture mirrors the all-statutory one but
     * stamps a dateOfJoining on the employee and seeds the GRATUITY_ACCRUAL
     * salary component so the addStatutoryLine resolves it.
     */
    private Payslip runPayrollGulfAccrual(int basic, LocalDate joinDate,
                                          BigDecimal mockedAccrual) {
        UUID runId = UUID.randomUUID();
        UUID empId = UUID.randomUUID();
        LocalDate start = LocalDate.of(2026, 6, 1);
        LocalDate end = LocalDate.of(2026, 6, 30);

        PayrollRun run = PayrollRun.builder()
                .id(runId).orgId(orgId).status("DRAFT")
                .periodStart(start).periodEnd(end).build();
        when(runRepo.findByIdAndOrgId(runId, orgId)).thenReturn(Optional.of(run));

        PayrollSettings settings = PayrollSettings.builder()
                .orgId(orgId).payFrequency("MONTHLY")
                .pfEnabled(false).esiEnabled(false).ptEnabled(false)
                .lwfEnabled(false).tdsEnabled(false).build();
        when(settingsRepo.findByOrgId(orgId)).thenReturn(Optional.of(settings));

        Employee emp = Employee.builder()
                .id(empId).orgId(orgId).userId(userId)
                .employeeCode("E1").employmentStatus("ACTIVE")
                .dateOfJoining(joinDate)
                .build();
        when(employeeRepo.findByOrgIdAndIsDeletedFalseAndEmploymentStatus(orgId, "ACTIVE"))
                .thenReturn(List.of(emp));

        SalaryComponent basicComp = comp("BASIC", "EARNING");
        SalaryComponent gratuityComp = comp("GRATUITY_ACCRUAL", "EMPLOYER_CONTRIBUTION");
        when(componentRepo.findByOrgIdAndActiveTrueOrderByCodeAsc(orgId)).thenReturn(
                List.of(basicComp, gratuityComp));
        when(payslipRepo.findByOrgIdAndPayrollRunId(orgId, runId)).thenReturn(List.of());

        EmployeeSalaryComponent line = EmployeeSalaryComponent.builder()
                .salaryComponent(basicComp).calculationType("FIXED")
                .amount(BigDecimal.valueOf(basic)).build();
        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .orgId(orgId).employeeId(empId).status("ACTIVE")
                .lines(new ArrayList<>(List.of(line))).build();
        when(structureRepo.findCurrentActive(orgId, empId)).thenReturn(Optional.of(structure));

        org.mockito.Mockito.lenient().when(leaveRequestRepo
                .findByOrgIdAndUserIdAndStatusInAndFromDateLessThanEqualAndToDateGreaterThanEqualAndIsDeletedFalse(
                        orgId, userId, List.of("APPROVED"), end, start))
                .thenReturn(List.of());

        if (mockedAccrual != null) {
            org.mockito.Mockito.lenient().when(gulfPayrollService.monthlyAccrual(
                    any(String.class), any(LocalDate.class),
                    any(LocalDate.class), any(BigDecimal.class)))
                    .thenReturn(mockedAccrual);
        }

        ArgumentCaptor<Payslip> captor = ArgumentCaptor.forClass(Payslip.class);
        when(payslipRepo.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));
        when(runRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.calculateRun(runId);
        return captor.getValue();
    }

    @Test
    void calculateRun_uaeOrg_addsGratuityAccrualAsEmployerContribution() {
        // AE org, 3-year-old employee → accrual is a non-deduction EMPLOYER line.
        when(countryAccess.isCountry("IN")).thenReturn(false);
        when(countryAccess.countryOf(orgId)).thenReturn("AE");

        Payslip slip = runPayrollGulfAccrual(
                10000, LocalDate.of(2023, 6, 1), new BigDecimal("583.33"));

        java.util.Optional<PayslipLine> grat = slip.getLines().stream()
                .filter(l -> "GRATUITY_ACCRUAL".equals(l.getSalaryComponent().getCode()))
                .findFirst();
        org.junit.jupiter.api.Assertions.assertTrue(grat.isPresent(),
                "AE payslip should carry a GRATUITY_ACCRUAL line");
        assertEquals("EMPLOYER_CONTRIBUTION", grat.get().getComponentType());
        assertEquals(0, grat.get().getAmount().compareTo(new BigDecimal("583.33")));
        // EMPLOYER_CONTRIBUTION bumps the employer bucket, NOT the employee net.
        assertEquals(0, slip.getEmployerContributions().compareTo(new BigDecimal("583.33")));
        assertEquals(0, slip.getGrossPay().compareTo(new BigDecimal("10000")));
        assertEquals(0, slip.getNetPay().compareTo(new BigDecimal("10000")));
    }

    @Test
    void calculateRun_omanOrg_addsGratuityAccrualAsEmployerContribution() {
        when(countryAccess.isCountry("IN")).thenReturn(false);
        when(countryAccess.countryOf(orgId)).thenReturn("OM");

        Payslip slip = runPayrollGulfAccrual(
                600, LocalDate.of(2024, 6, 1), new BigDecimal("25.00"));

        boolean hasAccrual = slip.getLines().stream()
                .anyMatch(l -> "GRATUITY_ACCRUAL".equals(l.getSalaryComponent().getCode())
                        && "EMPLOYER_CONTRIBUTION".equals(l.getComponentType())
                        && l.getAmount().compareTo(new BigDecimal("25.00")) == 0);
        org.junit.jupiter.api.Assertions.assertTrue(hasAccrual,
                "OM payslip should carry a GRATUITY_ACCRUAL line");
    }

    @Test
    void calculateRun_indiaOrg_neverInvokesGulfAccrual() {
        // Default IN — gulfStatutory branch must short-circuit.
        when(countryAccess.countryOf(orgId)).thenReturn("IN");

        Payslip slip = runPayrollGulfAccrual(
                30000, LocalDate.of(2023, 1, 1), null);

        boolean hasAccrual = slip.getLines().stream()
                .anyMatch(l -> "GRATUITY_ACCRUAL".equals(l.getSalaryComponent().getCode()));
        org.junit.jupiter.api.Assertions.assertFalse(hasAccrual,
                "India payslip must not carry a GRATUITY_ACCRUAL line");
        org.mockito.Mockito.verify(gulfPayrollService, org.mockito.Mockito.never())
                .monthlyAccrual(any(), any(), any(), any());
    }

    @Test
    void calculateRun_uaeOrgEmployeeNoJoinDate_skipsAccrual() {
        when(countryAccess.isCountry("IN")).thenReturn(false);
        when(countryAccess.countryOf(orgId)).thenReturn("AE");

        Payslip slip = runPayrollGulfAccrual(10000, null, null);

        boolean hasAccrual = slip.getLines().stream()
                .anyMatch(l -> "GRATUITY_ACCRUAL".equals(l.getSalaryComponent().getCode()));
        org.junit.jupiter.api.Assertions.assertFalse(hasAccrual,
                "AE employee with no dateOfJoining must not accrue gratuity");
        org.mockito.Mockito.verify(gulfPayrollService, org.mockito.Mockito.never())
                .monthlyAccrual(any(), any(), any(), any());
    }

    @Test
    void calculateRun_uaeOrg_skipsAllFourStatutoryDeductions() {
        // Override India default for this test: UAE org.
        when(countryAccess.isCountry("IN")).thenReturn(false);

        Payslip slip = runPayrollAllStatutoryEnabled(20000);
        java.util.Set<String> codes = slip.getLines().stream()
                .map(l -> l.getSalaryComponent().getCode())
                .collect(java.util.stream.Collectors.toSet());
        // None of the Indian statutory codes should be present.
        assertEquals(false, codes.contains("PF_EMPLOYEE"));
        assertEquals(false, codes.contains("PF_EMPLOYER"));
        assertEquals(false, codes.contains("ESI_EMPLOYEE"));
        assertEquals(false, codes.contains("ESI_EMPLOYER"));
        assertEquals(false, codes.contains("PT"));
        assertEquals(false, codes.contains("LWF"));
        // Gross equals BASIC because nothing was deducted.
        assertEquals(0, slip.getGrossPay().compareTo(new BigDecimal("20000")));
        assertEquals(0, slip.getNetPay().compareTo(new BigDecimal("20000")));
        // PT/LWF calculators must never even be invoked for UAE.
        org.mockito.Mockito.verify(ptCalculator, org.mockito.Mockito.never())
                .calculate(any(UUID.class), any(Employee.class), any(BigDecimal.class), any(LocalDate.class));
        org.mockito.Mockito.verify(lwfCalculator, org.mockito.Mockito.never())
                .calculate(any(UUID.class), any(BigDecimal.class), any(LocalDate.class));
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

    // ── Salary structure component lines (resolve-by-code + cascade) ────────

    private Employee structureEmployee(UUID employeeId) {
        Employee emp = Employee.builder().orgId(orgId).fullName("Worker").build();
        emp.setId(employeeId);
        when(employeeRepo.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId))
                .thenReturn(Optional.of(emp));
        // Lenient: the unknown-component path fails fast (before the deactivate
        // sweep) so it never queries the active structures.
        lenient().when(structureRepo.findByOrgIdAndEmployeeIdAndStatusOrderByEffectiveFromDesc(
                orgId, employeeId, "ACTIVE")).thenReturn(List.of());
        return emp;
    }

    @Test
    void createStructure_resolvesAndAttachesComponentLines() {
        UUID employeeId = UUID.randomUUID();
        structureEmployee(employeeId);
        SalaryComponent basic =
                SalaryComponent.builder().orgId(orgId).code("BASIC").name("Basic").build();
        basic.setId(UUID.randomUUID());
        SalaryComponent hra =
                SalaryComponent.builder().orgId(orgId).code("HRA").name("HRA").build();
        hra.setId(UUID.randomUUID());
        when(componentRepo.findByOrgIdAndCode(orgId, "BASIC")).thenReturn(Optional.of(basic));
        when(componentRepo.findByOrgIdAndCode(orgId, "HRA")).thenReturn(Optional.of(hra));
        when(structureRepo.save(any(EmployeeSalaryStructure.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        var lines = List.of(
                new com.katasticho.erp.payroll.dto.SalaryStructureRequest.ComponentLine(
                        "BASIC", "FIXED", new BigDecimal("30000"), null, null),
                new com.katasticho.erp.payroll.dto.SalaryStructureRequest.ComponentLine(
                        "HRA", "PERCENTAGE", null, new BigDecimal("40"), "BASIC"));

        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .effectiveFrom(LocalDate.of(2026, 4, 1)).build();
        EmployeeSalaryStructure saved = service.createStructure(employeeId, structure, lines);

        assertEquals(2, saved.getLines().size());
        EmployeeSalaryComponent l0 = saved.getLines().get(0);
        assertEquals("BASIC", l0.getSalaryComponent().getCode());
        assertEquals("FIXED", l0.getCalculationType());
        assertEquals(0, new BigDecimal("30000").compareTo(l0.getAmount()));
        assertEquals(orgId, l0.getOrgId());
        assertSame(saved, l0.getSalaryStructure());          // backref set for cascade
        EmployeeSalaryComponent l1 = saved.getLines().get(1);
        assertEquals("HRA", l1.getSalaryComponent().getCode());
        assertEquals("PERCENTAGE", l1.getCalculationType());
        assertEquals("BASIC", l1.getBaseComponentCode());
        assertEquals(0, new BigDecimal("40").compareTo(l1.getPercentage()));
    }

    @Test
    void createStructure_unknownComponentCode_throws() {
        UUID employeeId = UUID.randomUUID();
        structureEmployee(employeeId);
        when(componentRepo.findByOrgIdAndCode(orgId, "BOGUS")).thenReturn(Optional.empty());

        var lines = List.of(
                new com.katasticho.erp.payroll.dto.SalaryStructureRequest.ComponentLine(
                        "BOGUS", "FIXED", new BigDecimal("1"), null, null));
        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .effectiveFrom(LocalDate.of(2026, 4, 1)).build();

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.createStructure(employeeId, structure, lines));
        assertEquals("PAYROLL_UNKNOWN_COMPONENT", ex.getErrorCode());
        verify(structureRepo, never()).save(any());
    }

    @Test
    void createStructure_noLines_persistsHeaderOnly() {
        UUID employeeId = UUID.randomUUID();
        structureEmployee(employeeId);
        when(structureRepo.save(any(EmployeeSalaryStructure.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        EmployeeSalaryStructure structure = EmployeeSalaryStructure.builder()
                .effectiveFrom(LocalDate.of(2026, 4, 1)).build();
        EmployeeSalaryStructure saved = service.createStructure(employeeId, structure);

        assertTrue(saved.getLines().isEmpty());
        assertEquals("ACTIVE", saved.getStatus());
        assertEquals(orgId, saved.getOrgId());
    }
}
