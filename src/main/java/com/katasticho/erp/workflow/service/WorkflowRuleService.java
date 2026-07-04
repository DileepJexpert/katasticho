package com.katasticho.erp.workflow.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.event.DomainEvent;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.notification.EmailService;
import com.katasticho.erp.workflow.entity.WorkflowAction;
import com.katasticho.erp.workflow.entity.WorkflowCriterion;
import com.katasticho.erp.workflow.entity.WorkflowRule;
import com.katasticho.erp.workflow.repository.WorkflowRuleExecutionRepository;
import com.katasticho.erp.workflow.repository.WorkflowRuleRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The workflow-rules engine. CRUD for rules + {@link #evaluate} which the
 * {@code WorkflowRuleDomainEventHandler} calls for every domain event: it loads
 * the active rules for the (org, entity, trigger), evaluates their criteria
 * against the resolved document fields, and runs the matched rules' actions
 * (EMAIL / WEBHOOK / AI_SUGGESTION / FIELD_UPDATE). Idempotent per (rule, event)
 * via the execution log so the at-least-once bus can't double-fire.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WorkflowRuleService {

    private static final Set<String> OPERATORS = Set.of(
            "EQ", "NE", "GT", "GTE", "LT", "LTE", "CONTAINS", "IN", "IS_EMPTY", "IS_NOT_EMPTY");
    private static final Set<String> ACTION_TYPES = Set.of("EMAIL", "WEBHOOK", "AI_SUGGESTION", "FIELD_UPDATE");
    private static final Pattern PLACEHOLDER = Pattern.compile("\\{\\{\\s*([\\w.]+)\\s*}}");
    private static final String SUGGESTION_TYPE = "WORKFLOW_RULE";

    private final WorkflowRuleRepository ruleRepository;
    private final WorkflowRuleExecutionRepository executionRepository;
    private final WorkflowExecutionRecorder executionRecorder;
    private final WorkflowFieldResolver fieldResolver;
    private final WorkflowCriteriaEvaluator criteriaEvaluator;
    private final EmailService emailService;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final List<WorkflowFieldMutator> fieldMutators;
    private final RestTemplate gspRestTemplate;
    private final ObjectMapper objectMapper;

    // ── CRUD ────────────────────────────────────────────────────────────────

    @Transactional
    public WorkflowRule create(WorkflowRule rule) {
        validate(rule);
        rule.setOrgId(TenantContext.getCurrentOrgId());
        rule.setCreatedBy(TenantContext.getCurrentUserId());
        return ruleRepository.save(rule);
    }

    @Transactional
    public WorkflowRule update(UUID id, WorkflowRule patch) {
        WorkflowRule rule = load(id);
        rule.setName(patch.getName());
        rule.setDescription(patch.getDescription());
        rule.setEntityType(patch.getEntityType());
        rule.setTriggerEvent(patch.getTriggerEvent());
        rule.setMatchType(patch.getMatchType());
        rule.setCriteria(patch.getCriteria());
        rule.setActions(patch.getActions());
        rule.setRunOrder(patch.getRunOrder());
        validate(rule);
        return ruleRepository.save(rule);
    }

    @Transactional
    public WorkflowRule toggle(UUID id, boolean active) {
        WorkflowRule rule = load(id);
        rule.setActive(active);
        return ruleRepository.save(rule);
    }

    @Transactional
    public void delete(UUID id) {
        WorkflowRule rule = load(id);
        rule.setDeleted(true);
        ruleRepository.save(rule);
    }

    @Transactional(readOnly = true)
    public WorkflowRule get(UUID id) {
        return load(id);
    }

    @Transactional(readOnly = true)
    public Page<WorkflowRule> list(Pageable pageable) {
        return ruleRepository.findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), pageable);
    }

    @Transactional(readOnly = true)
    public Page<?> executions(UUID ruleId, Pageable pageable) {
        load(ruleId); // tenant check
        return executionRepository.findByOrgIdAndRuleIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), ruleId, pageable);
    }

    // ── Evaluation (called by the domain-event handler) ──────────────────────

    @Transactional
    public void evaluate(DomainEvent event) {
        UUID orgId = event.getOrgId();
        List<WorkflowRule> rules = ruleRepository
                .findByOrgIdAndEntityTypeAndTriggerEventAndActiveTrueAndIsDeletedFalseOrderByRunOrderAsc(
                        orgId, event.getEntityType(), event.getEventType());
        if (rules.isEmpty()) {
            return;
        }

        // The domain-event worker thread does NOT populate TenantContext (the bus
        // never sets it; the existing handlers pass event.getOrgId() explicitly).
        // Our action executors, the InvoiceFieldMutator, AiSuggestionService.requireOrgId,
        // and the execution recorder all read TenantContext, so establish it from the
        // event for the duration of evaluation and restore it afterwards (mirrors
        // DailyReportReminderJob / RecurringDocumentJob). Without this the execution
        // dedupe row (org_id NOT NULL) never commits and matched EMAIL/WEBHOOK actions
        // re-fire on every at-least-once retry.
        UUID priorOrg = TenantContext.getCurrentOrgId();
        try {
            TenantContext.setCurrentOrgId(orgId);
            Map<String, Object> fields = fieldResolver.resolve(event);

            for (WorkflowRule rule : rules) {
                try {
                    if (event.getId() != null && executionRepository
                            .existsByOrgIdAndRuleIdAndEventIdAndIsDeletedFalse(orgId, rule.getId(), event.getId())) {
                        continue; // already run for this event (retry-safe)
                    }
                    if (!criteriaEvaluator.matches(rule.getMatchType(), rule.getCriteria(), fields)) {
                        continue; // no side effects — safe to re-evaluate on a retry
                    }
                    ActionOutcome outcome = executeActions(rule, event.getEntityType(), event.getEntityId(), fields);
                    executionRecorder.record(rule.getId(), event.getId(), event.getEntityType(),
                            event.getEntityId(), true, outcome.status(), outcome.ran(), outcome.detail());
                } catch (Exception e) {
                    // Per-rule isolation: one bad rule must not fail the event (which
                    // would retry-loop and starve the AI / e-invoice handlers).
                    log.warn("Workflow rule {} failed on event {}: {}", rule.getId(), event.getId(), e.getMessage());
                }
            }
        } finally {
            TenantContext.setCurrentOrgId(priorOrg);
        }
    }

    /** Dry-run: resolve fields, evaluate criteria, and DESCRIBE (never execute) the actions. */
    @Transactional(readOnly = true)
    public Map<String, Object> dryRun(WorkflowRule rule, String entityType, UUID entityId) {
        validate(rule);
        Map<String, Object> fields = fieldResolver.resolve(
                entityType != null ? entityType : rule.getEntityType(), entityId, Map.of());
        boolean matched = criteriaEvaluator.matches(rule.getMatchType(), rule.getCriteria(), fields);
        List<String> planned = new ArrayList<>();
        if (matched) {
            for (WorkflowAction a : rule.getActions()) {
                planned.add(describeAction(a, fields));
            }
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("matched", matched);
        out.put("resolvedFields", fields);
        out.put("plannedActions", planned);
        return out;
    }

    // ── Action execution ─────────────────────────────────────────────────────

    private record ActionOutcome(String status, int ran, Map<String, Object> detail) {}

    private ActionOutcome executeActions(WorkflowRule rule, String entityType, UUID entityId,
                                         Map<String, Object> fields) {
        Map<String, Object> detail = new LinkedHashMap<>();
        int ran = 0;
        boolean anyFailed = false;
        int i = 0;
        for (WorkflowAction action : rule.getActions()) {
            String key = (action.getType() == null ? "action" : action.getType()) + "#" + (i++);
            try {
                switch (action.getType() == null ? "" : action.getType().toUpperCase()) {
                    case "EMAIL" -> executeEmail(action, fields);
                    case "WEBHOOK" -> executeWebhook(action, rule, entityType, entityId, fields);
                    case "AI_SUGGESTION" -> executeAiSuggestion(action, entityType, entityId, fields);
                    case "FIELD_UPDATE" -> executeFieldUpdate(action, entityType, entityId);
                    default -> throw new BusinessException("Unknown action type: " + action.getType(),
                            "WORKFLOW_BAD_ACTION", HttpStatus.BAD_REQUEST);
                }
                detail.put(key, "ok");
                ran++;
            } catch (Exception e) {
                detail.put(key, "failed: " + e.getMessage());
                anyFailed = true;
            }
        }
        return new ActionOutcome(anyFailed ? "ACTION_FAILED" : "MATCHED", ran, detail);
    }

    private void executeEmail(WorkflowAction action, Map<String, Object> fields) {
        Map<String, Object> cfg = config(action);
        String to = template(str(cfg.get("to")), fields);
        if (to == null || to.isBlank()) {
            throw new BusinessException("EMAIL action has no recipient", "WORKFLOW_EMAIL_NO_TO", HttpStatus.BAD_REQUEST);
        }
        String subject = template(str(cfg.getOrDefault("subject", "Workflow notification")), fields);
        String body = template(str(cfg.getOrDefault("body", "")), fields);
        emailService.sendHtml(to, subject, body);
    }

    private void executeWebhook(WorkflowAction action, WorkflowRule rule, String entityType,
                                UUID entityId, Map<String, Object> fields) {
        Map<String, Object> cfg = config(action);
        String url = str(cfg.get("url"));
        validateWebhookUrl(url);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("event", rule.getTriggerEvent());
        body.put("entityType", entityType);
        body.put("entityId", entityId == null ? null : entityId.toString());
        body.put("ruleId", rule.getId() == null ? null : rule.getId().toString());
        body.put("ruleName", rule.getName());
        body.put("fields", fields);
        String json;
        try {
            json = objectMapper.writeValueAsString(body);
        } catch (Exception e) {
            throw new BusinessException("Could not serialise webhook body", "WORKFLOW_WEBHOOK_BODY", HttpStatus.INTERNAL_SERVER_ERROR);
        }
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-Katixo-Event", rule.getTriggerEvent());
        String secret = str(cfg.get("secret"));
        if (secret != null && !secret.isBlank()) {
            headers.set("X-Katixo-Signature", hmacHex(json, secret));
        }
        gspRestTemplate.postForEntity(url, new HttpEntity<>(json, headers), String.class);
    }

    private void executeAiSuggestion(WorkflowAction action, String entityType, UUID entityId,
                                     Map<String, Object> fields) {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (entityId != null && aiSuggestionRepository.existsOpenSuggestion(
                orgId, entityType, entityId, null, SUGGESTION_TYPE, List.of("PENDING", "DEFERRED"))) {
            return; // idempotent — one open suggestion per (entity, workflow) at a time
        }
        Map<String, Object> cfg = config(action);
        AiSuggestion s = AiSuggestion.builder()
                .entityType(entityType).entityId(entityId)
                .suggestionType(SUGGESTION_TYPE)
                .suggestedAction(template(str(cfg.getOrDefault("message", "Workflow rule matched")), fields))
                .reasoning(template(str(cfg.getOrDefault("reasoning", "")), fields))
                .priority(str(cfg.getOrDefault("priority", "MEDIUM")))
                .suggestedValue(new HashMap<>(fields))
                .build();
        aiSuggestionService.createSuggestion(s);
    }

    private void executeFieldUpdate(WorkflowAction action, String entityType, UUID entityId) {
        Map<String, Object> cfg = config(action);
        String field = str(cfg.get("field"));
        if (field == null || field.isBlank()) {
            throw new BusinessException("FIELD_UPDATE has no field", "WORKFLOW_FIELD_MISSING", HttpStatus.BAD_REQUEST);
        }
        WorkflowFieldMutator mutator = mutatorFor(entityType);
        if (!mutator.allowedFields().contains(field)) {
            throw new BusinessException("Field not writable by a workflow rule: " + field,
                    "WORKFLOW_FIELD_NOT_WRITABLE", HttpStatus.BAD_REQUEST);
        }
        mutator.apply(entityId, field, cfg.get("value"));
    }

    private WorkflowFieldMutator mutatorFor(String entityType) {
        return fieldMutators.stream().filter(m -> m.supports(entityType)).findFirst()
                .orElseThrow(() -> new BusinessException(
                        "No FIELD_UPDATE mutator for " + entityType,
                        "WORKFLOW_NO_MUTATOR", HttpStatus.BAD_REQUEST));
    }

    // ── Validation ────────────────────────────────────────────────────────

    private void validate(WorkflowRule rule) {
        if (rule.getName() == null || rule.getName().isBlank()) {
            throw new BusinessException("Name is required", "WORKFLOW_NAME_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (rule.getEntityType() == null || rule.getEntityType().isBlank()) {
            throw new BusinessException("Entity type is required", "WORKFLOW_ENTITY_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (rule.getTriggerEvent() == null || rule.getTriggerEvent().isBlank()) {
            throw new BusinessException("Trigger event is required", "WORKFLOW_TRIGGER_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        if (rule.getCriteria() != null) {
            for (WorkflowCriterion c : rule.getCriteria()) {
                if (c.getField() == null || c.getField().isBlank()) {
                    throw new BusinessException("A criterion has no field", "WORKFLOW_CRITERION_FIELD", HttpStatus.BAD_REQUEST);
                }
                String op = c.getOperator() == null ? "" : c.getOperator().toUpperCase();
                if (!OPERATORS.contains(op)) {
                    throw new BusinessException("Unknown operator: " + c.getOperator(), "WORKFLOW_BAD_OPERATOR", HttpStatus.BAD_REQUEST);
                }
            }
        }
        if (rule.getActions() == null || rule.getActions().isEmpty()) {
            throw new BusinessException("At least one action is required", "WORKFLOW_ACTIONS_REQUIRED", HttpStatus.BAD_REQUEST);
        }
        for (WorkflowAction a : rule.getActions()) {
            String type = a.getType() == null ? "" : a.getType().toUpperCase();
            if (!ACTION_TYPES.contains(type)) {
                throw new BusinessException("Unknown action type: " + a.getType(), "WORKFLOW_BAD_ACTION", HttpStatus.BAD_REQUEST);
            }
            Map<String, Object> cfg = a.getConfig() == null ? Map.of() : a.getConfig();
            switch (type) {
                case "EMAIL" -> requireCfg(cfg, "to", "EMAIL action needs a recipient");
                case "WEBHOOK" -> validateWebhookUrl(str(cfg.get("url")));
                case "AI_SUGGESTION" -> requireCfg(cfg, "message", "AI_SUGGESTION needs a message");
                case "FIELD_UPDATE" -> validateFieldUpdate(rule.getEntityType(), cfg);
            }
        }
    }

    private void validateFieldUpdate(String entityType, Map<String, Object> cfg) {
        String field = str(cfg.get("field"));
        if (field == null || field.isBlank()) {
            throw new BusinessException("FIELD_UPDATE needs a field", "WORKFLOW_FIELD_MISSING", HttpStatus.BAD_REQUEST);
        }
        // Fail fast at save if a mutator exists but the field isn't allowlisted.
        fieldMutators.stream().filter(m -> m.supports(entityType)).findFirst().ifPresent(m -> {
            if (!m.allowedFields().contains(field)) {
                throw new BusinessException("Field not writable by a workflow rule: " + field,
                        "WORKFLOW_FIELD_NOT_WRITABLE", HttpStatus.BAD_REQUEST);
            }
        });
    }

    /**
     * SSRF guard: reject non-https URLs and any host that resolves to an
     * internal/loopback/link-local/site-local address. Resolve-and-inspect (not
     * literal string matching) so encoded IP literals (decimal/hex/octal), IPv6
     * loopback forms, and public hostnames that resolve to internal ranges (incl.
     * the 169.254.169.254 cloud-metadata endpoint) are all caught. A DNS-rebind
     * between this check and the actual POST is a residual we accept for a
     * semi-trusted admin-configured webhook.
     */
    void validateWebhookUrl(String url) {
        if (url == null || url.isBlank()) {
            throw new BusinessException("WEBHOOK action needs a URL", "WORKFLOW_WEBHOOK_NO_URL", HttpStatus.BAD_REQUEST);
        }
        java.net.URI uri;
        try {
            uri = java.net.URI.create(url.trim());
        } catch (Exception e) {
            throw new BusinessException("Invalid webhook URL", "WORKFLOW_WEBHOOK_BAD_URL", HttpStatus.BAD_REQUEST);
        }
        if (!"https".equalsIgnoreCase(uri.getScheme())) {
            throw new BusinessException("Webhook URL must be https", "WORKFLOW_WEBHOOK_NOT_HTTPS", HttpStatus.BAD_REQUEST);
        }
        String host = uri.getHost();
        if (host == null || host.isBlank()) {
            // URI.getHost() returns null for malformed/unbracketed IPv6 or hosts with
            // illegal chars — refuse rather than let RestTemplate resolve it.
            throw new BusinessException("Webhook host is not allowed", "WORKFLOW_WEBHOOK_INTERNAL_HOST", HttpStatus.BAD_REQUEST);
        }
        String cleanHost = host;
        if (cleanHost.startsWith("[") && cleanHost.endsWith("]")) {
            cleanHost = cleanHost.substring(1, cleanHost.length() - 1); // strip IPv6 brackets
        }
        java.net.InetAddress[] addrs;
        try {
            addrs = java.net.InetAddress.getAllByName(cleanHost);
        } catch (java.net.UnknownHostException e) {
            throw new BusinessException("Webhook host could not be resolved",
                    "WORKFLOW_WEBHOOK_UNRESOLVABLE", HttpStatus.BAD_REQUEST);
        }
        if (addrs.length == 0) {
            throw new BusinessException("Webhook host could not be resolved",
                    "WORKFLOW_WEBHOOK_UNRESOLVABLE", HttpStatus.BAD_REQUEST);
        }
        for (java.net.InetAddress addr : addrs) {
            if (isBlockedAddress(addr)) {
                throw new BusinessException("Webhook host is not allowed (internal/loopback)",
                        "WORKFLOW_WEBHOOK_INTERNAL_HOST", HttpStatus.BAD_REQUEST);
            }
        }
    }

    /** True for loopback/any-local/link-local (incl. 169.254 metadata)/site-local/multicast/CGNAT
     *  and IPv6 Unique-Local Addresses (fc00::/7), which the InetAddress predicates do not cover. */
    private static boolean isBlockedAddress(java.net.InetAddress addr) {
        if (addr.isAnyLocalAddress() || addr.isLoopbackAddress() || addr.isLinkLocalAddress()
                || addr.isSiteLocalAddress() || addr.isMulticastAddress()) {
            return true;
        }
        byte[] b = addr.getAddress();
        if (b.length == 4) {
            int o0 = b[0] & 0xFF, o1 = b[1] & 0xFF;
            if (o0 == 100 && o1 >= 64 && o1 <= 127) return true; // 100.64.0.0/10 CGNAT
        } else if (b.length == 16 && (b[0] & 0xFE) == 0xFC) {
            // RFC 4193 IPv6 Unique-Local Addresses (fc00::/7). Inet6Address.isSiteLocalAddress()
            // only matches the deprecated fec0::/10 block, NOT fc00::/7 — the modern IPv6 private
            // range on internal/dual-stack networks — so an fd00::/8 host would otherwise slip
            // through the guard. Check the top 7 bits explicitly.
            return true;
        }
        return false;
    }

    // ── helpers ───────────────────────────────────────────────────────────

    private WorkflowRule load(UUID id) {
        return ruleRepository.findByIdAndOrgIdAndIsDeletedFalse(id, TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Workflow rule", id));
    }

    private static Map<String, Object> config(WorkflowAction a) {
        return a.getConfig() == null ? Map.of() : a.getConfig();
    }

    private static void requireCfg(Map<String, Object> cfg, String key, String msg) {
        Object v = cfg.get(key);
        if (v == null || v.toString().isBlank()) {
            throw new BusinessException(msg, "WORKFLOW_CFG_" + key.toUpperCase(), HttpStatus.BAD_REQUEST);
        }
    }

    private String describeAction(WorkflowAction a, Map<String, Object> fields) {
        Map<String, Object> cfg = config(a);
        return switch (a.getType() == null ? "" : a.getType().toUpperCase()) {
            case "EMAIL" -> "Email → " + template(str(cfg.get("to")), fields);
            case "WEBHOOK" -> "POST webhook → " + str(cfg.get("url"));
            case "AI_SUGGESTION" -> "AI inbox suggestion: " + template(str(cfg.get("message")), fields);
            case "FIELD_UPDATE" -> "Set " + str(cfg.get("field")) + " = " + str(cfg.get("value"));
            default -> "Unknown action";
        };
    }

    /** Replace {{field}} placeholders with the resolved field values. */
    static String template(String s, Map<String, Object> fields) {
        if (s == null || s.indexOf("{{") < 0) return s;
        Matcher m = PLACEHOLDER.matcher(s);
        StringBuilder out = new StringBuilder();
        while (m.find()) {
            Object v = fields.get(m.group(1));
            m.appendReplacement(out, Matcher.quoteReplacement(v == null ? "" : v.toString()));
        }
        m.appendTail(out);
        return out.toString();
    }

    static String hmacHex(String body, String secret) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] h = mac.doFinal(body.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(h.length * 2);
            for (byte b : h) {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private static String str(Object o) {
        return o == null ? null : o.toString();
    }
}
