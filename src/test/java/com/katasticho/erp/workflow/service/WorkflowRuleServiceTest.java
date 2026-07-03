package com.katasticho.erp.workflow.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.notification.EmailService;
import com.katasticho.erp.workflow.entity.WorkflowAction;
import com.katasticho.erp.workflow.entity.WorkflowCriterion;
import com.katasticho.erp.workflow.entity.WorkflowRule;
import com.katasticho.erp.workflow.repository.WorkflowRuleExecutionRepository;
import com.katasticho.erp.workflow.repository.WorkflowRuleRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class WorkflowRuleServiceTest {

    @Mock private WorkflowRuleRepository ruleRepository;
    @Mock private WorkflowRuleExecutionRepository executionRepository;
    @Mock private WorkflowExecutionRecorder executionRecorder;
    @Mock private WorkflowFieldResolver fieldResolver;
    @Mock private EmailService emailService;
    @Mock private AiSuggestionService aiSuggestionService;
    @Mock private AiSuggestionRepository aiSuggestionRepository;
    @Mock private org.springframework.web.client.RestTemplate gspRestTemplate;
    @Mock private InvoiceRepository invoiceRepository;

    private WorkflowRuleService svc;
    private final UUID orgId = UUID.randomUUID();
    private final UUID invoiceId = UUID.randomUUID();
    private final UUID eventId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        InvoiceFieldMutator mutator = new InvoiceFieldMutator(invoiceRepository);
        svc = new WorkflowRuleService(ruleRepository, executionRepository, executionRecorder,
                fieldResolver, new WorkflowCriteriaEvaluator(), emailService, aiSuggestionService,
                aiSuggestionRepository, List.of(mutator), gspRestTemplate, new ObjectMapper());
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        when(ruleRepository.save(any())).thenAnswer(i -> {
            WorkflowRule r = i.getArgument(0);
            if (r.getId() == null) r.setId(UUID.randomUUID());
            return r;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private DomainEvent invoicePostedEvent() {
        return DomainEvent.builder()
                .id(eventId).orgId(orgId)
                .eventType("INVOICE_POSTED").entityType("INVOICE").entityId(invoiceId)
                .payload(Map.of("invoiceNumber", "INV-001"))
                .build();
    }

    private WorkflowRule rule(WorkflowCriterion criterion, WorkflowAction action) {
        WorkflowRule r = WorkflowRule.builder()
                .name("r").entityType("INVOICE").triggerEvent("INVOICE_POSTED").matchType("ALL")
                .criteria(criterion == null ? List.of() : List.of(criterion))
                .actions(List.of(action)).active(true).build();
        r.setId(UUID.randomUUID());
        r.setOrgId(orgId);
        return r;
    }

    private WorkflowAction email() {
        return WorkflowAction.builder().type("EMAIL")
                .config(Map.of("to", "boss@acme.com", "subject", "Big invoice {{invoiceNumber}}",
                        "body", "Amount {{totalAmount}}")).build();
    }

    // ── evaluate ──

    @Test
    void matching_rule_fires_email_and_records_execution() {
        WorkflowRule r = rule(WorkflowCriterion.builder().field("totalAmount").operator("GT").value("100000").build(),
                email());
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(r));
        when(fieldResolver.resolve(any(DomainEvent.class)))
                .thenReturn(Map.of("invoiceNumber", "INV-001", "totalAmount", new BigDecimal("150000")));
        when(executionRepository.existsByOrgIdAndRuleIdAndEventIdAndIsDeletedFalse(orgId, r.getId(), eventId))
                .thenReturn(false);

        svc.evaluate(invoicePostedEvent());

        // templated subject/body resolved, email sent
        verify(emailService).sendHtml(eq("boss@acme.com"), eq("Big invoice INV-001"), eq("Amount 150000"));
        verify(executionRecorder).record(eq(r.getId()), eq(eventId), eq("INVOICE"), eq(invoiceId),
                eq(true), eq("MATCHED"), eq(1), anyMap());
    }

    @Test
    void non_matching_rule_does_nothing() {
        WorkflowRule r = rule(WorkflowCriterion.builder().field("totalAmount").operator("GT").value("999999").build(),
                email());
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(r));
        when(fieldResolver.resolve(any(DomainEvent.class)))
                .thenReturn(Map.of("totalAmount", new BigDecimal("1000")));

        svc.evaluate(invoicePostedEvent());

        verify(emailService, never()).sendHtml(any(), any(), any());
        verify(executionRecorder, never()).record(any(), any(), any(), any(), anyBoolean(), any(), anyInt(), anyMap());
    }

    @Test
    void already_run_event_is_skipped_for_idempotency() {
        WorkflowRule r = rule(null, email());
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(r));
        when(fieldResolver.resolve(any(DomainEvent.class))).thenReturn(Map.of());
        when(executionRepository.existsByOrgIdAndRuleIdAndEventIdAndIsDeletedFalse(orgId, r.getId(), eventId))
                .thenReturn(true); // already processed

        svc.evaluate(invoicePostedEvent());

        verify(emailService, never()).sendHtml(any(), any(), any());
    }

    @Test
    void ai_suggestion_action_is_idempotent_when_one_is_open() {
        WorkflowRule r = rule(null, WorkflowAction.builder().type("AI_SUGGESTION")
                .config(Map.of("message", "Review this invoice")).build());
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(r));
        when(fieldResolver.resolve(any(DomainEvent.class))).thenReturn(Map.of());
        when(aiSuggestionRepository.existsOpenSuggestion(orgId, "INVOICE", invoiceId, null, "WORKFLOW_RULE",
                List.of("PENDING", "DEFERRED"))).thenReturn(true);

        svc.evaluate(invoicePostedEvent());

        verify(aiSuggestionService, never()).createSuggestion(any(AiSuggestion.class));
    }

    @Test
    void one_failing_rule_does_not_break_others() {
        WorkflowRule bad = rule(null, WorkflowAction.builder().type("EMAIL")
                .config(Map.of("to", "")).build()); // no recipient → action fails
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(bad));
        when(fieldResolver.resolve(any(DomainEvent.class))).thenReturn(Map.of());

        svc.evaluate(invoicePostedEvent()); // must not throw

        verify(executionRecorder).record(eq(bad.getId()), eq(eventId), any(), any(),
                eq(true), eq("ACTION_FAILED"), eq(0), anyMap());
    }

    // ── validation / security ──

    @Test
    void create_rejects_webhook_to_an_internal_host() {
        WorkflowRule r = rule(null, WorkflowAction.builder().type("WEBHOOK")
                .config(Map.of("url", "https://10.0.0.5/hook")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_WEBHOOK_INTERNAL_HOST");
    }

    @Test
    void create_rejects_non_https_webhook() {
        WorkflowRule r = rule(null, WorkflowAction.builder().type("WEBHOOK")
                .config(Map.of("url", "http://example.com/hook")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_WEBHOOK_NOT_HTTPS");
    }

    @Test
    void create_rejects_field_update_outside_the_allowlist() {
        // status is NOT in InvoiceFieldMutator's allowlist {notes, termsAndConditions}
        WorkflowRule r = rule(null, WorkflowAction.builder().type("FIELD_UPDATE")
                .config(Map.of("field", "status", "value", "PAID")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_FIELD_NOT_WRITABLE");
    }

    @Test
    void field_update_to_an_allowlisted_field_calls_the_mutator() {
        WorkflowRule r = rule(null, WorkflowAction.builder().type("FIELD_UPDATE")
                .config(Map.of("field", "notes", "value", "flagged by workflow")).build());
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(r));
        when(fieldResolver.resolve(any(DomainEvent.class))).thenReturn(Map.of());
        var inv = new com.katasticho.erp.ar.entity.Invoice();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(java.util.Optional.of(inv));

        svc.evaluate(invoicePostedEvent());

        assertThat(inv.getNotes()).isEqualTo("flagged by workflow");
        verify(invoiceRepository).save(inv);
    }

    @Test
    void create_requires_at_least_one_action() {
        WorkflowRule r = WorkflowRule.builder().name("r").entityType("INVOICE")
                .triggerEvent("INVOICE_POSTED").matchType("ALL").criteria(List.of()).actions(List.of()).build();
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_ACTIONS_REQUIRED");
    }

    // ── worker-thread tenant context (evaluate is called with NO TenantContext) ──

    @Test
    void evaluate_on_worker_thread_resolves_org_from_event_not_thread_local() {
        // The real domain-event worker never populates TenantContext — simulate it.
        TenantContext.clear();
        WorkflowRule r = rule(null, WorkflowAction.builder().type("FIELD_UPDATE")
                .config(Map.of("field", "notes", "value", "flagged by workflow")).build());
        when(ruleRepository.findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                orgId, "INVOICE", "INVOICE_POSTED")).thenReturn(List.of(r));
        when(fieldResolver.resolve(any(DomainEvent.class))).thenReturn(Map.of());
        var inv = new com.katasticho.erp.ar.entity.Invoice();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(java.util.Optional.of(inv));

        svc.evaluate(invoicePostedEvent());

        // Mutator resolved the invoice with the EVENT's org (not the null ThreadLocal)…
        verify(invoiceRepository).findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId);
        assertThat(inv.getNotes()).isEqualTo("flagged by workflow");
        // …the dedupe/execution row was recorded (idempotency backstop lives)…
        verify(executionRecorder).record(eq(r.getId()), eq(eventId), eq("INVOICE"), eq(invoiceId),
                eq(true), eq("MATCHED"), eq(1), anyMap());
        // …and TenantContext was restored to its prior (empty) state afterwards.
        assertThat(TenantContext.getCurrentOrgId()).isNull();
    }

    // ── SSRF webhook guard (resolve-and-inspect) ──

    @Test
    void create_rejects_webhook_to_ipv4_loopback() {
        WorkflowRule r = rule(null, WorkflowAction.builder().type("WEBHOOK")
                .config(Map.of("url", "https://127.0.0.1/hook")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_WEBHOOK_INTERNAL_HOST");
    }

    @Test
    void create_rejects_webhook_to_ipv6_loopback() {
        WorkflowRule r = rule(null, WorkflowAction.builder().type("WEBHOOK")
                .config(Map.of("url", "https://[::1]/hook")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_WEBHOOK_INTERNAL_HOST");
    }

    @Test
    void create_rejects_webhook_to_cloud_metadata_ip() {
        // 169.254.169.254 is link-local (AWS/GCP/Azure metadata) — must be blocked.
        WorkflowRule r = rule(null, WorkflowAction.builder().type("WEBHOOK")
                .config(Map.of("url", "https://169.254.169.254/latest/meta-data/")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_WEBHOOK_INTERNAL_HOST");
    }

    @Test
    void create_rejects_webhook_to_decimal_encoded_loopback() {
        // 2130706433 == 127.0.0.1. The OLD literal-prefix check let this through
        // (a real SSRF hole); resolve-and-inspect catches it.
        WorkflowRule r = rule(null, WorkflowAction.builder().type("WEBHOOK")
                .config(Map.of("url", "https://2130706433/hook")).build());
        assertThatThrownBy(() -> svc.create(r))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "WORKFLOW_WEBHOOK_INTERNAL_HOST");
    }
}
