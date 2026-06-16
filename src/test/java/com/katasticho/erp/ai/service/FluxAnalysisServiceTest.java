package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.dto.report.ProfitLossResponse;
import com.katasticho.erp.accounting.dto.report.ProfitLossResponse.AccountLine;
import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.accounting.service.FinancialReportService;
import com.katasticho.erp.ai.config.AiConfig;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.common.context.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class FluxAnalysisServiceTest {

    private final FinancialReportService financialReportService = mock(FinancialReportService.class);
    private final FiscalPeriodRepository fiscalPeriodRepository = mock(FiscalPeriodRepository.class);
    private final AiSuggestionRepository aiSuggestionRepository = mock(AiSuggestionRepository.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);
    private final AiConfig aiConfig = new AiConfig();
    private final ClaudeApiClient claudeApiClient = mock(ClaudeApiClient.class);

    private final FluxAnalysisService service = new FluxAnalysisService(
            financialReportService, fiscalPeriodRepository,
            aiSuggestionRepository, aiSuggestionService, aiConfig, claudeApiClient);

    private final UUID orgId = UUID.randomUUID();
    private final UUID periodId = UUID.randomUUID();
    private final LocalDate today = LocalDate.of(2026, 6, 5); // May is the prior month

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        aiConfig.setAnthropicApiKey(""); // disable AI by default (deterministic)
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private AccountLine line(String code, String name, String amount) {
        return new AccountLine(UUID.randomUUID(), code, name, new BigDecimal(amount));
    }

    private ProfitLossResponse pl(LocalDate start, LocalDate end,
                                  List<AccountLine> rev, List<AccountLine> exp) {
        BigDecimal r = rev.stream().map(AccountLine::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal e = exp.stream().map(AccountLine::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return new ProfitLossResponse(start, end, "INR", r, e, r.subtract(e), rev, exp);
    }

    @Test
    void noPeriod_doesNothing() {
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(Optional.empty());

        assertThat(service.draftForLastMonth(today)).isZero();
        verifyNoInteractions(aiSuggestionService);
    }

    @Test
    void existingOpenSuggestion_isDeduped() {
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(Optional.of(period()));
        when(aiSuggestionRepository.existsOpenSuggestion(
                eq(orgId), eq("FISCAL_PERIOD"), eq(periodId), any(), eq("FLUX_ANALYSIS"),
                eq(Set.of("PENDING", "DEFERRED"))))
                .thenReturn(true);

        assertThat(service.draftForLastMonth(today)).isZero();
        verifyNoInteractions(aiSuggestionService);
    }

    @Test
    void materialMovements_createSuggestionWithDeterministicCommentary() {
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(Optional.of(period()));
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);

        // Revenue jumped 80%, one expense doubled — both material.
        AccountLine revA = line("4000", "Product Sales", "180000");
        AccountLine expA = line("5400", "Rent", "60000");
        AccountLine expB = line("5800", "Misc", "200"); // tiny, ignored
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31)))
                .thenReturn(pl(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31),
                        List.of(revA), List.of(expA, expB)));

        AccountLine revAPrev = new AccountLine(revA.accountId(), "4000", "Product Sales", new BigDecimal("100000"));
        AccountLine expAPrev = new AccountLine(expA.accountId(), "5400", "Rent", new BigDecimal("30000"));
        AccountLine expBPrev = new AccountLine(expB.accountId(), "5800", "Misc", new BigDecimal("100"));
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30)))
                .thenReturn(pl(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30),
                        List.of(revAPrev), List.of(expAPrev, expBPrev)));

        assertThat(service.draftForLastMonth(today)).isEqualTo(1);

        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(cap.capture());
        AiSuggestion s = cap.getValue();
        assertThat(s.getSuggestionType()).isEqualTo("FLUX_ANALYSIS");
        assertThat(s.getModelName()).isEqualTo("deterministic_rules"); // AI off
        assertThat(s.getReasoning()).contains("Flux 2026-05 vs 2026-04");
        assertThat(s.getSuggestedValue()).containsKey("materialMovements");
        @SuppressWarnings("unchecked")
        List<Object> rows = (List<Object>) s.getSuggestedValue().get("materialMovements");
        // Two material lines (revenue + rent), tiny misc filtered out
        assertThat(rows).hasSize(2);
        // AI is disabled → no Claude call
        verifyNoInteractions(claudeApiClient);
    }

    @Test
    void aiEnabled_callsClaudeAndIncludesCommentary() {
        aiConfig.setAnthropicApiKey("test-key");
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(Optional.of(period()));
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);
        AccountLine revA = line("4000", "Sales", "200000");
        AccountLine expA = line("5400", "Rent", "80000");
        AccountLine revAPrev = new AccountLine(revA.accountId(), "4000", "Sales", new BigDecimal("100000"));
        AccountLine expAPrev = new AccountLine(expA.accountId(), "5400", "Rent", new BigDecimal("30000"));
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31)))
                .thenReturn(pl(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31),
                        List.of(revA), List.of(expA)));
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30)))
                .thenReturn(pl(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30),
                        List.of(revAPrev), List.of(expAPrev)));
        when(claudeApiClient.sendMessage(any(), any())).thenReturn("Sales doubled on the launch of X; rent up 167% suggests a posting error.");

        assertThat(service.draftForLastMonth(today)).isEqualTo(1);

        ArgumentCaptor<AiSuggestion> cap = ArgumentCaptor.forClass(AiSuggestion.class);
        verify(aiSuggestionService).createSuggestion(cap.capture());
        assertThat(cap.getValue().getReasoning()).contains("posting error");
        assertThat(cap.getValue().getModelName()).isNotEqualTo("deterministic_rules");
        verify(claudeApiClient).sendMessage(any(), any());
    }

    @Test
    void noMaterialMovements_skipsSuggestion() {
        when(fiscalPeriodRepository.findByOrgIdAndPeriodYearAndPeriodMonth(orgId, 2026, 5))
                .thenReturn(Optional.of(period()));
        when(aiSuggestionRepository.existsOpenSuggestion(any(), any(), any(), any(), any(), any()))
                .thenReturn(false);
        // Same numbers in both periods → no flux to report.
        AccountLine rev = line("4000", "Sales", "100000");
        AccountLine exp = line("5400", "Rent", "30000");
        AccountLine revPrev = new AccountLine(rev.accountId(), "4000", "Sales", new BigDecimal("100000"));
        AccountLine expPrev = new AccountLine(exp.accountId(), "5400", "Rent", new BigDecimal("30000"));
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31)))
                .thenReturn(pl(LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31),
                        List.of(rev), List.of(exp)));
        when(financialReportService.generateProfitLoss(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30)))
                .thenReturn(pl(LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30),
                        List.of(revPrev), List.of(expPrev)));

        assertThat(service.draftForLastMonth(today)).isZero();
        verifyNoInteractions(aiSuggestionService);
    }

    private FiscalPeriod period() {
        FiscalPeriod p = new FiscalPeriod();
        p.setId(periodId);
        p.setOrgId(orgId);
        p.setPeriodYear(2026);
        p.setPeriodMonth(5);
        p.setStatus("OPEN");
        return p;
    }
}
