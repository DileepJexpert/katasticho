package com.katasticho.erp.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.dto.AgentChatDtos.AgentChatResponse;
import com.katasticho.erp.ai.dto.AiQueryResponse;
import com.katasticho.erp.ai.dto.ConversationalEntryDtos.EntryDraftResult;
import com.katasticho.erp.ar.dto.OverdueCustomerResponse;
import com.katasticho.erp.ar.service.CreditReminderService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConversationalAgentServiceTest {

    @Mock private VisionModelRouter modelRouter;
    @Mock private NlpQueryService nlpQueryService;
    @Mock private ConversationalEntryService conversationalEntryService;
    @Mock private CreditReminderService creditReminderService;
    private ConversationalAgentService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ConversationalAgentService(modelRouter, nlpQueryService,
                conversationalEntryService, creditReminderService, new ObjectMapper());
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private AiQueryResponse queryResp(String answer) {
        return new AiQueryResponse(answer, "SELECT 1", List.of(),
                new AiQueryResponse.QueryMetadata("revenue", 5, 1));
    }

    private EntryDraftResult draft(boolean drafted, UUID suggestionId) {
        return new EntryDraftResult(drafted, suggestionId, UUID.randomUUID(), "PAYMENT",
                "Drafted: Dr Rent 5000 / Cr Cash 5000.", new BigDecimal("5000"), 0.9,
                List.of(), List.of(), "Drafted a payment of ₹5000.");
    }

    private OverdueCustomerResponse overdue(String name, String amt, long days) {
        return new OverdueCustomerResponse(UUID.randomUUID(), name, "9999999999",
                new BigDecimal(amt), new BigDecimal(amt), LocalDate.now().minusDays(days),
                days, 2, null, null, List.of());
    }

    @Test
    void llmPlansQuery_runsNlpAndReturnsAnswer() {
        when(modelRouter.sendMessage(anyString(), anyString())).thenReturn(
                "{\"tool\":\"query_data\",\"args\":{\"question\":\"revenue last month\"}}");
        when(nlpQueryService.processQuery("revenue last month")).thenReturn(queryResp("Your revenue was ₹1,20,000."));

        AgentChatResponse r = service.chat("how much did I make last month");

        assertThat(r.tool()).isEqualTo("query_data");
        assertThat(r.reply()).contains("1,20,000");
        verify(nlpQueryService).processQuery("revenue last month");
    }

    @Test
    void llmPlansDraft_createsDraftAndFlagsActionRequired() {
        UUID suggestionId = UUID.randomUUID();
        when(modelRouter.sendMessage(anyString(), anyString())).thenReturn(
                "here you go: {\"tool\":\"draft_entry\",\"args\":{\"text\":\"paid 5000 cash for shop rent\"}}");
        when(conversationalEntryService.draftFromText("paid 5000 cash for shop rent"))
                .thenReturn(draft(true, suggestionId));

        AgentChatResponse r = service.chat("paid 5000 cash for shop rent");

        assertThat(r.tool()).isEqualTo("draft_entry");
        assertThat(r.actionRequired()).isTrue();
        assertThat(r.draftSuggestionId()).isEqualTo(suggestionId);
        assertThat(r.reply()).contains("AI Inbox");
    }

    @Test
    void llmPlansOverdue_summarisesCustomers() {
        when(modelRouter.sendMessage(anyString(), anyString()))
                .thenReturn("{\"tool\":\"list_overdue\",\"args\":{}}");
        when(creditReminderService.getOverdueCustomers()).thenReturn(List.of(
                overdue("MediMart", "15000", 45),
                overdue("City Chemist", "2000", 10)));

        AgentChatResponse r = service.chat("who owes me money");

        assertThat(r.tool()).isEqualTo("list_overdue");
        assertThat(r.reply()).contains("2 customer(s) overdue");
        assertThat(r.reply()).contains("MediMart");
        assertThat(r.reply()).contains("17000"); // total
    }

    @Test
    void plannerUnavailable_fallsBackToRules_draft() {
        // Model throws (e.g. local server down) → keyword rules route the payment.
        when(modelRouter.sendMessage(anyString(), anyString()))
                .thenThrow(new RuntimeException("connection refused"));
        when(conversationalEntryService.draftFromText(anyString()))
                .thenReturn(draft(true, UUID.randomUUID()));

        AgentChatResponse r = service.chat("received 8000 from Sharma by upi");

        assertThat(r.tool()).isEqualTo("draft_entry");
        verify(conversationalEntryService).draftFromText("received 8000 from Sharma by upi");
    }

    @Test
    void plannerGarbage_fallsBackToRules_overdue() {
        when(modelRouter.sendMessage(anyString(), anyString())).thenReturn("I'm not sure how to help");
        when(creditReminderService.getOverdueCustomers()).thenReturn(List.of());

        AgentChatResponse r = service.chat("show me outstanding receivables");

        assertThat(r.tool()).isEqualTo("list_overdue");
        assertThat(r.reply()).contains("current");
    }

    @Test
    void llmPlansNone_returnsHelpfulReplyWithoutCallingTools() {
        when(modelRouter.sendMessage(anyString(), anyString())).thenReturn(
                "{\"tool\":\"none\",\"reply\":\"Hi! Ask me about your sales or record a payment.\"}");

        AgentChatResponse r = service.chat("hello there");

        assertThat(r.tool()).isEqualTo("none");
        assertThat(r.reply()).contains("Ask me about your sales");
        verifyNoInteractions(nlpQueryService, conversationalEntryService, creditReminderService);
    }

    @Test
    void queryFailure_returnsFriendlyMessageNotError() {
        when(modelRouter.sendMessage(anyString(), anyString())).thenReturn(
                "{\"tool\":\"query_data\",\"args\":{\"question\":\"gibberish\"}}");
        when(nlpQueryService.processQuery(anyString()))
                .thenThrow(new BusinessException("Failed to execute the generated query", "ERR_AI_SQL_EXECUTION"));

        AgentChatResponse r = service.chat("gibberish");

        assertThat(r.tool()).isEqualTo("query_data");
        assertThat(r.reply()).contains("couldn't answer");
    }

    @Test
    void blankMessage_isHandledWithoutPlanning() {
        AgentChatResponse r = service.chat("   ");

        assertThat(r.tool()).isEqualTo("none");
        verifyNoInteractions(modelRouter);
    }
}
