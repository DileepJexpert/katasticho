package com.katasticho.erp.payroll.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
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
                journalService, accountRepo, leaveRequestRepo);
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
}
