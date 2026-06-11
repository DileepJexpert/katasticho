package com.katasticho.erp.ai.service;

import com.katasticho.erp.accounting.entity.FiscalPeriod;
import com.katasticho.erp.accounting.repository.FiscalPeriodRepository;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ar.dto.OverdueCustomerResponse;
import com.katasticho.erp.ar.dto.ReminderTextResponse;
import com.katasticho.erp.ar.service.CreditReminderService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Proactive agents (Phase G) — the "the system tells you first" layer. Instead
 * of waiting to be asked, these sweeps surface ready-to-act items in the AI
 * Inbox:
 *
 * <ul>
 *   <li><b>Collections reminders:</b> one suggestion per overdue customer with
 *       a ready-to-send WhatsApp/SMS message drafted by
 *       {@link CreditReminderService}.</li>
 *   <li><b>Month-close checklist:</b> once a month ends, if its fiscal period is
 *       still open, a checklist nudge with the standard close steps.</li>
 *   <li><b>Anomaly sweep:</b> delegates to {@link RuleBasedAiAgentService},
 *       which already drafts and de-dupes anomaly suggestions.</li>
 * </ul>
 *
 * <p>Every suggestion is idempotent via
 * {@link AiSuggestionRepository#existsOpenSuggestion} so repeated runs don't
 * pile up duplicates. Nothing is sent or posted automatically — the human acts
 * from the Inbox.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProactiveAgentService {

    static final String COLLECTIONS = "COLLECTIONS_REMINDER";
    static final String MONTH_CLOSE = "MONTH_CLOSE_CHECKLIST";
    private static final Set<String> OPEN_STATUSES = Set.of("PENDING", "DEFERRED");

    private final CreditReminderService creditReminderService;
    private final FiscalPeriodRepository fiscalPeriodRepository;
    private final RuleBasedAiAgentService ruleBasedAiAgentService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final AiSuggestionService aiSuggestionService;

    public record ProactiveRunResult(int collections, int monthClose, int anomalies) {}

    /** Run all proactive agents for the current tenant. */
    @Transactional
    public ProactiveRunResult runAll() {
        int collections = draftCollectionsReminders();
        int monthClose = draftMonthCloseChecklist(LocalDate.now());
        int anomalies = ruleBasedAiAgentService.runRuleChecks(30).createdSuggestions();
        log.info("Proactive sweep: {} collections, {} month-close, {} anomalies",
                collections, monthClose, anomalies);
        return new ProactiveRunResult(collections, monthClose, anomalies);
    }

    // ── Collections reminders ───────────────────────────────────────────

    @Transactional
    public int draftCollectionsReminders() {
        UUID orgId = requireOrgId();
        List<OverdueCustomerResponse> overdue = creditReminderService.getOverdueCustomers();
        int created = 0;

        for (OverdueCustomerResponse c : overdue) {
            if (aiSuggestionRepository.existsOpenSuggestion(
                    orgId, "CONTACT", c.contactId(), null, COLLECTIONS, OPEN_STATUSES)) {
                continue;
            }

            String message = null;
            String whatsappUrl = null;
            try {
                ReminderTextResponse rt = creditReminderService.generateReminderMessage(c.contactId());
                message = rt.message();
                whatsappUrl = rt.whatsappUrl();
            } catch (Exception e) {
                log.debug("Reminder text unavailable for {}: {}", c.contactId(), e.getMessage());
            }

            Map<String, Object> value = new LinkedHashMap<>();
            value.put("customer", c.contactName());
            value.put("phone", c.phone());
            value.put("overdueAmount", c.overdueAmount());
            value.put("maxDaysOverdue", c.maxDaysOverdue());
            value.put("invoiceCount", c.invoiceCount());
            if (message != null) value.put("draftMessage", message);
            if (whatsappUrl != null) value.put("whatsappUrl", whatsappUrl);

            String priority = c.maxDaysOverdue() >= 30 ? "HIGH" : "MEDIUM";
            BigDecimal score = c.maxDaysOverdue() >= 30 ? new BigDecimal("80") : new BigDecimal("55");

            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .orgId(orgId)
                    .entityType("CONTACT")
                    .entityId(c.contactId())
                    .suggestionType(COLLECTIONS)
                    .suggestedAction("SEND_PAYMENT_REMINDER")
                    .suggestedValue(value)
                    .reasoning(c.contactName() + " has " + c.overdueAmount()
                            + " overdue across " + c.invoiceCount() + " invoice(s), up to "
                            + c.maxDaysOverdue() + " days late.")
                    .confidence(new BigDecimal("0.900"))
                    .agentName("collections_agent")
                    .modelName("deterministic_rules")
                    .modelVersion("1")
                    .promptVersion("none")
                    .priority(priority)
                    .priorityScore(score)
                    .status("PENDING")
                    .build());
            created++;
        }
        return created;
    }

    // ── Month-close checklist ───────────────────────────────────────────

    @Transactional
    public int draftMonthCloseChecklist(LocalDate today) {
        UUID orgId = requireOrgId();

        // The month that just ended.
        LocalDate priorMonth = today.withDayOfMonth(1).minusMonths(1);
        int year = priorMonth.getYear();
        int month = priorMonth.getMonthValue();

        Optional<FiscalPeriod> period = fiscalPeriodRepository
                .findByOrgIdAndPeriodYearAndPeriodMonth(orgId, year, month);
        // Only nudge if the period exists and is still open.
        if (period.isEmpty() || period.get().isClosed()) {
            return 0;
        }
        UUID periodId = period.get().getId();

        if (aiSuggestionRepository.existsOpenSuggestion(
                orgId, "FISCAL_PERIOD", periodId, null, MONTH_CLOSE, OPEN_STATUSES)) {
            return 0;
        }

        long pendingInbox = aiSuggestionRepository.countByOrgIdAndStatus(orgId, "PENDING");

        Map<String, Object> value = new LinkedHashMap<>();
        value.put("periodYear", year);
        value.put("periodMonth", month);
        value.put("pendingInboxItems", pendingInbox);
        value.put("checklist", List.of(
                "Clear pending AI Inbox items",
                "Reconcile bank statements",
                "Verify GST output vs input (GSTR-3B)",
                "Post any accruals/prepaid adjustments",
                "Review the Trial Balance",
                "Close the period"));

        aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(orgId)
                .entityType("FISCAL_PERIOD")
                .entityId(periodId)
                .suggestionType(MONTH_CLOSE)
                .suggestedAction("REVIEW_MONTH_CLOSE")
                .suggestedValue(value)
                .reasoning(String.format("%04d-%02d has ended but isn't closed yet. "
                        + "%d inbox item(s) need attention before you close.", year, month, pendingInbox))
                .confidence(new BigDecimal("1.000"))
                .agentName("month_close_agent")
                .modelName("deterministic_rules")
                .modelVersion("1")
                .promptVersion("none")
                .priority("MEDIUM")
                .priorityScore(new BigDecimal("60"))
                .status("PENDING")
                .build());
        return 1;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
