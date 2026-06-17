package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.ai.dto.AiAgentRunResponse;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.ProactiveAgentService.ProactiveRunResult;
import com.katasticho.erp.ar.dto.OverdueCustomerResponse;
import com.katasticho.erp.ar.dto.ReminderTextResponse;
import com.katasticho.erp.ar.service.CreditReminderService;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ProactiveAgentServiceTest {

    private final CreditReminderService creditReminderService = mock(CreditReminderService.class);
    private final FiscalPeriodRepository fiscalPeriodRepository = mock(FiscalPeriodRepository.class);
    private final RuleBasedAiAgentService ruleBasedAiAgentService = mock(RuleBasedAiAgentService.class);
    private final AiSuggestionRepository aiSuggestionRepository = mock(AiSuggestionRepository.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);
    private final com.katasticho.erp.ai.service.FluxAnalysisService fluxAnalysisService =
            mock(com.katasticho.erp.ai.service.FluxAnalysisService.class);
    private final TransactionCategorizationService transactionCategorizationService =
            mock(TransactionCategorizationService.class);

    private final ProactiveAgentService service = new ProactiveAgentService(
            creditReminderService, fiscalPeriodRepository, ruleBasedAiAgentService,
            aiSuggestionRepository, aiSuggestionService, fluxAnalysisService,
            transactionCategorizationService);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(aiSuggestionService.createSuggestion(any())).thenAnswer(inv -> inv.getArgument(0));
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);
        when(aiSuggestionRepository.countByOrgIdAndStatus(any(), any())).thenReturn(3L);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Collections reminders ───────────────────────────────────────────

    @Test
    void draftsOneReminderPerOverdueCustomer() {
        UUID c1 = UUID.randomUUID();
        UUID c2 = UUID.randomUUID();
        when(creditReminderService.getOverdueCustomers()).thenReturn(List.of(
                overdue(c1, "MediMart", new BigDecimal("15000"), 45),
                overdue(c2, "City Chemist", new BigDecimal("2000"), 10)));
        when(creditReminderService.generateReminderMessage(any()))
                .thenReturn(new ReminderTextResponse(c1, "MediMart", "9999", "Please pay", "https://wa.me/..."));

        int created = service.draftCollectionsReminders();

        assertThat(created).isEqualTo(2);
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService, times(2)).createSuggestion(cap.capture());

        AiSuggestion s1 = cap.getAllValues().get(0);
        assertThat(s1.getSuggestionType()).isEqualTo("COLLECTIONS_REMINDER");
        assertThat(s1.getEntityType()).isEqualTo("CONTACT");
        assertThat(s1.getEntityId()).isEqualTo(c1);
        assertThat(s1.getPriority()).isEqualTo("HIGH");          // 45 days
        assertThat(s1.getSuggestedValue()).containsKey("draftMessage");

        // 10 days overdue → MEDIUM
        assertThat(cap.getAllValues().get(1).getPriority()).isEqualTo("MEDIUM");
    }

    @Test
    void skipsCustomerWithOpenReminder() {
        UUID c1 = UUID.randomUUID();
        when(creditReminderService.getOverdueCustomers())
                .thenReturn(List.of(overdue(c1, "MediMart", new BigDecimal("15000"), 45)));
        when(aiSuggestionRepository.existsOpenSuggestion(
                orgId, "CONTACT", c1, null, "COLLECTIONS_REMINDER",
                java.util.Set.of("PENDING", "DEFERRED")))
                .thenReturn(true);

        int created = service.draftCollectionsReminders();

        assertThat(created).isZero();
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void reminderTextFailureStillDraftsSuggestion() {
        UUID c1 = UUID.randomUUID();
        when(creditReminderService.getOverdueCustomers())
                .thenReturn(List.of(overdue(c1, "MediMart", new BigDecimal("15000"), 45)));
        when(creditReminderService.generateReminderMessage(any()))
                .thenThrow(new RuntimeException("no template"));

        int created = service.draftCollectionsReminders();

        assertThat(created).isEqualTo(1);  // resilient: drafts without the message
    }

    // ── Month-close checklist ───────────────────────────────────────────

    @Test
    void draftsChecklistWhenPriorPeriodOpen() {
        // "today" = 5 May 2025 → prior month = April 2025
        LocalDate today = LocalDate.of(2025, 5, 5);
        FiscalPeriod april = FiscalPeriod.builder()
                .id(UUID.randomUUID()).orgId(orgId).periodYear(2025).periodMonth(4)
                .status("OPEN").build();
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2025, 4))
                .thenReturn(Optional.of(april));

        int created = service.draftMonthCloseChecklist(today);

        assertThat(created).isEqualTo(1);
        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(cap.capture());
        AiSuggestion s = cap.getValue();
        assertThat(s.getSuggestionType()).isEqualTo("MONTH_CLOSE_CHECKLIST");
        assertThat(s.getEntityType()).isEqualTo("FISCAL_PERIOD");
        assertThat(s.getSuggestedValue()).containsEntry("periodMonth", 4);
        assertThat(s.getSuggestedValue()).containsEntry("pendingInboxItems", 3L);
    }

    @Test
    void noChecklistWhenPriorPeriodClosed() {
        LocalDate today = LocalDate.of(2025, 5, 5);
        FiscalPeriod april = FiscalPeriod.builder()
                .id(UUID.randomUUID()).orgId(orgId).periodYear(2025).periodMonth(4)
                .status("CLOSED").build();
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2025, 4))
                .thenReturn(Optional.of(april));

        assertThat(service.draftMonthCloseChecklist(today)).isZero();
        verify(aiSuggestionService, never()).createSuggestion(any());
    }

    @Test
    void noChecklistWhenPriorPeriodAbsent() {
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(any(), anyInt(), anyInt()))
                .thenReturn(Optional.empty());
        assertThat(service.draftMonthCloseChecklist(LocalDate.of(2025, 5, 5))).isZero();
    }

    @Test
    void januaryRollsBackToPriorDecember() {
        LocalDate today = LocalDate.of(2025, 1, 10);
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2024, 12))
                .thenReturn(Optional.of(FiscalPeriod.builder()
                        .id(UUID.randomUUID()).orgId(orgId).periodYear(2024).periodMonth(12)
                        .status("OPEN").build()));

        assertThat(service.draftMonthCloseChecklist(today)).isEqualTo(1);
        verify(fiscalPeriodRepository).findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2024, 12);
    }

    // ── runAll ──────────────────────────────────────────────────────────

    @Test
    void runAllAggregatesAllAgents() {
        when(creditReminderService.getOverdueCustomers())
                .thenReturn(List.of(overdue(UUID.randomUUID(), "MediMart", new BigDecimal("15000"), 45)));
        when(creditReminderService.generateReminderMessage(any()))
                .thenReturn(new ReminderTextResponse(null, "MediMart", "9", "pay", "url"));
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(any(), anyInt(), anyInt()))
                .thenReturn(Optional.empty());
        when(ruleBasedAiAgentService.runRuleChecks(30)).thenReturn(
                new AiAgentRunResponse(LocalDate.now(), LocalDate.now(), 0, 0, 0, 4, 0));
        when(transactionCategorizationService.backfillFromHistory(anyInt())).thenReturn(7);

        ProactiveRunResult r = service.runAll();

        assertThat(r.collections()).isEqualTo(1);
        assertThat(r.monthClose()).isZero();
        assertThat(r.anomalies()).isEqualTo(4);
        assertThat(r.categorize()).isEqualTo(7);
        verify(ruleBasedAiAgentService).runRuleChecks(30);
        verify(transactionCategorizationService).backfillFromHistory(365);
    }

    // ── Fixtures ──────────────────────────────────────────────────────────

    private static OverdueCustomerResponse overdue(UUID id, String name, BigDecimal amount, long days) {
        return new OverdueCustomerResponse(id, name, "9999999999", amount, amount,
                LocalDate.now().minusDays(days), days, 2, null, null, List.of());
    }
}
