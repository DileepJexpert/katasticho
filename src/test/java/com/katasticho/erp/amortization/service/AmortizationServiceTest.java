package com.katasticho.erp.amortization.service;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.amortization.entity.AmortizationSchedule;
import com.katasticho.erp.amortization.repository.AmortizationEntryRepository;
import com.katasticho.erp.amortization.repository.AmortizationScheduleRepository;
import com.katasticho.erp.common.context.TenantContext;
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
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class AmortizationServiceTest {

    @Mock private AmortizationScheduleRepository scheduleRepository;
    @Mock private AmortizationEntryRepository entryRepository;
    @Mock private JournalService journalService;
    private AmortizationService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new AmortizationService(scheduleRepository, entryRepository, journalService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(journalService.postJournal(any())).thenAnswer(i -> {
            JournalEntry je = new JournalEntry();
            je.setId(UUID.randomUUID());
            return je;
        });
        when(scheduleRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        when(entryRepository.save(any())).thenAnswer(i -> i.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private AmortizationSchedule prepaid(String total, int periods, int startY, int startM) {
        return AmortizationSchedule.builder().id(UUID.randomUUID()).orgId(orgId)
                .scheduleType("PREPAID").description("Insurance").totalAmount(new BigDecimal(total))
                .startYear(startY).startMonth(startM).numberOfPeriods(periods)
                .debitAccountCode("5400").creditAccountCode("1450")
                .recognizedAmount(BigDecimal.ZERO).status("ACTIVE").build();
    }

    @Test
    void periodAmount_lastPeriodAbsorbsRoundingResidual() {
        // 1000 / 3 = 333.33 ; last = 1000 - 333.33*2 = 333.34
        AmortizationSchedule s = prepaid("1000", 3, 2026, 4);
        assertEquals(0, new BigDecimal("333.33").compareTo(service.periodAmount(s, 0)));
        assertEquals(0, new BigDecimal("333.33").compareTo(service.periodAmount(s, 1)));
        assertEquals(0, new BigDecimal("333.34").compareTo(service.periodAmount(s, 2)));
        // sums to exactly 1000
        BigDecimal sum = service.periodAmount(s, 0)
                .add(service.periodAmount(s, 1)).add(service.periodAmount(s, 2));
        assertEquals(0, new BigDecimal("1000").compareTo(sum));
    }

    @Test
    void run_postsBalancedJournalForDueSchedulesOnly() {
        AmortizationSchedule due = prepaid("120000", 12, 2026, 4);     // Apr 2026 start
        AmortizationSchedule future = prepaid("60000", 6, 2026, 8);    // starts Aug — not due in May
        when(scheduleRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE"))
                .thenReturn(List.of(due, future));
        when(entryRepository.existsByOrgIdAndScheduleIdAndPeriodYearAndPeriodMonth(any(), any(), anyInt(), anyInt()))
                .thenReturn(false);

        // Run May 2026 → only `due` is in window (index 1)
        Map<String, Object> r = service.run(2026, 5);

        assertEquals(1, r.get("scheduleCount"));
        assertEquals(0, new BigDecimal("10000.00").compareTo((BigDecimal) r.get("totalRecognized")));

        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        var lines = cap.getValue().lines();
        BigDecimal dr = lines.stream().map(l -> l.debit()).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal cr = lines.stream().map(l -> l.credit()).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, dr.compareTo(cr));                              // balanced
        assertEquals(0, new BigDecimal("10000.00").compareTo(dr));     // DR 5400 expense
    }

    @Test
    void run_idempotent_skipsAlreadyPostedPeriod() {
        AmortizationSchedule s = prepaid("120000", 12, 2026, 4);
        when(scheduleRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE"))
                .thenReturn(List.of(s));
        when(entryRepository.existsByOrgIdAndScheduleIdAndPeriodYearAndPeriodMonth(orgId, s.getId(), 2026, 5))
                .thenReturn(true); // already posted

        Map<String, Object> r = service.run(2026, 5);
        assertEquals(0, r.get("scheduleCount"));
        verify(journalService, never()).postJournal(any());
    }

    @Test
    void run_lastPeriod_marksScheduleCompleted() {
        // 2-period schedule starting Apr 2026; run May 2026 (index 1 = last)
        AmortizationSchedule s = prepaid("1000", 2, 2026, 4);
        s.setRecognizedAmount(new BigDecimal("500")); // first period already recognised
        when(scheduleRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE"))
                .thenReturn(List.of(s));
        when(entryRepository.existsByOrgIdAndScheduleIdAndPeriodYearAndPeriodMonth(any(), any(), anyInt(), anyInt()))
                .thenReturn(false);

        service.run(2026, 5);

        assertEquals("COMPLETED", s.getStatus());
        assertEquals(0, new BigDecimal("1000").compareTo(s.getRecognizedAmount()));
    }

    @Test
    void deferredIncome_postsDebitDeferredCreditRevenue() {
        AmortizationSchedule s = AmortizationSchedule.builder().id(UUID.randomUUID()).orgId(orgId)
                .scheduleType("DEFERRED_INCOME").description("AMC advance")
                .totalAmount(new BigDecimal("12000")).startYear(2026).startMonth(4).numberOfPeriods(12)
                .debitAccountCode("2400").creditAccountCode("4000") // DR Deferred income / CR Revenue
                .recognizedAmount(BigDecimal.ZERO).status("ACTIVE").build();
        when(scheduleRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtAsc(orgId, "ACTIVE"))
                .thenReturn(List.of(s));
        when(entryRepository.existsByOrgIdAndScheduleIdAndPeriodYearAndPeriodMonth(any(), any(), anyInt(), anyInt()))
                .thenReturn(false);

        service.run(2026, 4);

        ArgumentCaptor<JournalPostRequest> cap = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService).postJournal(cap.capture());
        var lines = cap.getValue().lines();
        assertTrue(lines.stream().anyMatch(l ->
                l.accountCode().equals("2400") && l.debit().compareTo(new BigDecimal("1000")) == 0));
        assertTrue(lines.stream().anyMatch(l ->
                l.accountCode().equals("4000") && l.credit().compareTo(new BigDecimal("1000")) == 0));
    }
}
