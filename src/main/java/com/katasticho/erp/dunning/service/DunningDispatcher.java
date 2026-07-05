package com.katasticho.erp.dunning.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.dunning.entity.DunningLevel;
import com.katasticho.erp.dunning.entity.DunningLog;
import com.katasticho.erp.dunning.repository.DunningLogRepository;
import com.katasticho.erp.notification.EmailService;
import com.katasticho.erp.notification.whatsapp.WhatsAppDocumentService;
import com.katasticho.erp.notification.whatsapp.WhatsAppMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.util.*;

/**
 * Sends ONE dunning notice for a single (invoice, level) in its OWN transaction
 * (REQUIRES_NEW), using a CLAIM-BEFORE-SEND protocol so the partial unique index
 * {@code uq_dunning_log_sent} is the real idempotency gate:
 * <ol>
 *   <li>viability pre-check (has the channel a target?) — no side effect, no claim;</li>
 *   <li>insert + FLUSH the SENT dunning_log row — a concurrent sweep's competing
 *       claim fails the unique index HERE (before any send), so a duplicate
 *       notice is never dispatched;</li>
 *   <li>deliver over the channel; if not delivered, throw to roll back the claim
 *       so the notice is retried next sweep (no false-positive SENT row).</li>
 * </ol>
 * Because each call is its own transaction, a claim collision rolls back only
 * THIS invoice — it can never poison the batch sweep (which holds no transaction).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DunningDispatcher {

    private static final List<String> OPEN_SUGGESTION_STATUSES = List.of("PENDING", "DEFERRED");
    private static final String SUGGESTION_TYPE = "DUNNING";
    private static final String DEFAULT_TEMPLATE =
            "Dear {{customer}}, invoice {{invoiceNumber}} for {{amount}} is {{days}} day(s) overdue "
                    + "(was due {{dueDate}}). Please arrange payment at the earliest. — {{orgName}}";

    private final DunningLogRepository logRepository;
    private final EmailService emailService;
    private final WhatsAppDocumentService whatsAppDocumentService;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final Clock clock;

    /** Outcome of a dispatch attempt for the sweep's counters. */
    public enum Outcome { SENT, SKIPPED }

    /** Thrown when a channel could not deliver — rolls back the SENT claim so it retries. */
    static class NotDeliveredException extends RuntimeException {
        NotDeliveredException(String msg) { super(msg); }
    }

    /**
     * @throws org.springframework.dao.DataIntegrityViolationException if a concurrent
     *         sweep already claimed this (invoice, level) — the caller treats it as skipped.
     * @throws NotDeliveredException if the channel had a target but did not deliver.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Outcome dispatch(UUID orgId, Invoice invoice, Contact contact, DunningLevel level,
                            long days, String orgName) {
        String channel = level.getChannel();
        // 1. viability — no side effects, no claim (so it retries when the target is fixed)
        if ("EMAIL".equals(channel) && (contact == null || contact.getEmail() == null || contact.getEmail().isBlank())) {
            return Outcome.SKIPPED;
        }
        if ("WHATSAPP".equals(channel) && contact == null) {
            return Outcome.SKIPPED;
        }
        // 2. claim the SENT slot — the unique index arbitrates concurrent sweeps BEFORE any send
        DunningLog claim = DunningLog.builder()
                .invoiceId(invoice.getId())
                .contactId(invoice.getContactId())
                .dunningLevelId(level.getId())
                .daysOverdue((int) days)
                .amount(invoice.getBalanceDue())
                .channel(channel)
                .outcome("SENT")
                .detail(channelDetail(channel, contact))
                .sentAt(clock.instant())
                .build();
        claim.setOrgId(orgId); // explicit — never rely on the ThreadLocal fallback for the org key
        logRepository.saveAndFlush(claim); // DataIntegrityViolationException on a competing claim

        // 3. deliver; if the channel can't send, throw to roll back the claim (retry next sweep)
        String message = render(level.getMessageTemplate(), invoice, contact, days, orgName);
        if (!deliver(orgId, invoice, contact, level, message, days)) {
            throw new NotDeliveredException("channel " + channel + " did not deliver");
        }
        return Outcome.SENT;
    }

    private boolean deliver(UUID orgId, Invoice invoice, Contact contact, DunningLevel level,
                            String message, long days) {
        switch (level.getChannel()) {
            case "EMAIL" -> {
                String subject = render(level.getSubject() == null || level.getSubject().isBlank()
                        ? "Payment reminder: invoice {{invoiceNumber}}" : level.getSubject(),
                        invoice, contact, days, "");
                // Honour the actual send outcome (mirrors the WHATSAPP branch) — a
                // swallowed failure must NOT commit a false SENT that the partial
                // unique index then permanently suppresses; false → NotDelivered →
                // the claim rolls back and the level retries next sweep.
                return emailService.sendHtml(contact.getEmail(), subject, message);
            }
            case "WHATSAPP" -> {
                WhatsAppMessage msg = whatsAppDocumentService.sendReminder(contact.getId());
                return msg != null && "SENT".equalsIgnoreCase(msg.getStatus());
            }
            case "AI_INBOX" -> {
                raiseAiSuggestion(orgId, invoice, contact, level, message, days);
                return true;
            }
            default -> { // NONE — record the stage reached without notifying
                return true;
            }
        }
    }

    private void raiseAiSuggestion(UUID orgId, Invoice invoice, Contact contact, DunningLevel level,
                                   String message, long days) {
        Map<String, Object> value = new HashMap<>();
        value.put("invoiceNumber", invoice.getInvoiceNumber());
        value.put("amount", invoice.getBalanceDue());
        value.put("daysOverdue", days);
        value.put("level", level.getName());
        value.put("channel", level.getChannel());
        value.put("message", message);
        if (contact != null) {
            value.put("customer", contact.getDisplayName());
        }
        String priority = days >= 30 ? "HIGH" : "MEDIUM";
        BigDecimal score = BigDecimal.valueOf(Math.min(100, 40 + days));

        Optional<AiSuggestion> existing = aiSuggestionRepository
                .findFirstByOrgIdAndEntityTypeAndEntityIdAndSuggestionTypeAndStatusInOrderByCreatedAtDesc(
                        orgId, "INVOICE", invoice.getId(), SUGGESTION_TYPE, OPEN_SUGGESTION_STATUSES);
        if (existing.isPresent()) {
            AiSuggestion s = existing.get();
            if (score.compareTo(nz(s.getPriorityScore())) > 0) { // never downgrade
                s.setPriority(priority);
                s.setPriorityScore(score);
            }
            s.setReasoning(message);
            s.setSuggestedValue(value);
            aiSuggestionRepository.save(s);
        } else {
            aiSuggestionService.createSuggestion(AiSuggestion.builder()
                    .entityType("INVOICE").entityId(invoice.getId())
                    .suggestionType(SUGGESTION_TYPE).suggestedAction("SEND_DUNNING")
                    .reasoning(message).priority(priority).priorityScore(score)
                    .suggestedValue(value)
                    .confidence(new BigDecimal("0.900"))
                    .agentName("dunning_agent").modelName("deterministic_rules")
                    .status("PENDING")
                    .build());
        }
    }

    private String render(String template, Invoice inv, Contact contact, long days, String orgName) {
        String base = (template == null || template.isBlank()) ? DEFAULT_TEMPLATE : template;
        String customer = contact != null && contact.getDisplayName() != null ? contact.getDisplayName() : "Customer";
        return base
                .replace("{{customer}}", customer)
                .replace("{{amount}}", inv.getBalanceDue() == null ? "" : inv.getBalanceDue().toPlainString())
                .replace("{{days}}", String.valueOf(days))
                .replace("{{invoiceNumber}}", inv.getInvoiceNumber() == null ? "" : inv.getInvoiceNumber())
                .replace("{{dueDate}}", inv.getDueDate() == null ? "" : inv.getDueDate().toString())
                .replace("{{orgName}}", orgName == null ? "" : orgName);
    }

    private static String channelDetail(String channel, Contact contact) {
        return switch (channel) {
            case "EMAIL" -> "email:" + (contact == null ? "" : contact.getEmail());
            case "WHATSAPP" -> "whatsapp";
            case "AI_INBOX" -> "ai_inbox";
            default -> "no notification";
        };
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
