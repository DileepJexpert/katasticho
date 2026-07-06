package com.katasticho.erp.payment.service;

import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentForInvoiceRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.repository.AiSuggestionRepository;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.payment.entity.PaymentLink;
import com.katasticho.erp.payment.entity.PaymentWebhookEvent;
import com.katasticho.erp.payment.repository.PaymentLinkRepository;
import com.katasticho.erp.payment.repository.PaymentWebhookEventRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Creates payment-gateway links for invoices and processes the signed webhook
 * that settles them. The webhook path is the security-critical surface:
 * verify HMAC over the raw body, dedupe by event id AND captured-payment id,
 * resolve invoice+org solely from the stored link, and record the AR payment
 * idempotently. See {@link RazorpayClient} for the signature + transport.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentLinkService {

    /** Idempotent AI-Inbox flag raised when a gateway capture can't be applied. */
    private static final String UNAPPLIED_SUGGESTION_TYPE = "GATEWAY_CAPTURE_UNAPPLIED";
    private static final String PAYMENT_LINK_ENTITY = "PAYMENT_LINK";
    private static final List<String> OPEN_STATUSES = List.of("PENDING", "IN_PROGRESS");

    private final RazorpayClient razorpayClient;
    private final PaymentLinkRepository paymentLinkRepository;
    private final PaymentWebhookEventRepository webhookEventRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final PaymentService paymentService;
    private final AiSuggestionService aiSuggestionService;
    private final AiSuggestionRepository aiSuggestionRepository;
    private final AppUserRepository appUserRepository;
    private final EntityManager entityManager;
    private final Clock clock;

    // ── Create ──────────────────────────────────────────────────────────────

    @Transactional
    public PaymentLink createForInvoice(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        if (!List.of("SENT", "PARTIALLY_PAID", "OVERDUE").contains(invoice.getStatus())) {
            throw new BusinessException(
                    "A payment link can only be created for a sent, unpaid invoice (status: "
                            + invoice.getStatus() + ")",
                    "PAYLINK_INVOICE_NOT_PAYABLE", HttpStatus.BAD_REQUEST);
        }
        BigDecimal balance = invoice.getBalanceDue();
        if (balance == null || balance.signum() <= 0) {
            throw new BusinessException("Invoice has nothing outstanding to collect",
                    "PAYLINK_NOTHING_DUE", HttpStatus.BAD_REQUEST);
        }

        long amountPaise = balance.movePointRight(2).setScale(0, RoundingMode.HALF_UP).longValueExact();
        Contact contact = invoice.getContactId() == null ? null
                : contactRepository.findByIdAndOrgIdAndIsDeletedFalse(invoice.getContactId(), orgId).orElse(null);

        Map<String, Object> resp = razorpayClient.createPaymentLink(
                orgId, amountPaise, invoice.getCurrency(), invoice.getInvoiceNumber(),
                "Payment for invoice " + invoice.getInvoiceNumber(),
                contact != null ? contact.getDisplayName() : null,
                contact != null ? contact.getEmail() : null,
                contact != null ? firstNonBlank(contact.getMobile(), contact.getPhone()) : null);

        PaymentLink link = PaymentLink.builder()
                .invoiceId(invoiceId)
                .contactId(invoice.getContactId())
                .provider(RazorpayClient.PROVIDER)
                .providerLinkId(asString(resp.get("id")))
                .referenceId(invoice.getInvoiceNumber())
                .shortUrl(asString(resp.get("short_url")))
                .amount(balance)
                .currency(invoice.getCurrency())
                .status("CREATED")
                .build();
        link.setOrgId(orgId);
        link.setCreatedBy(TenantContext.getCurrentUserId());
        return paymentLinkRepository.save(link);
    }

    @Transactional(readOnly = true)
    public List<PaymentLink> listForInvoice(UUID invoiceId) {
        return paymentLinkRepository.findByOrgIdAndInvoiceIdAndIsDeletedFalseOrderByCreatedAtDesc(
                TenantContext.getCurrentOrgId(), invoiceId);
    }

    // ── Webhook ─────────────────────────────────────────────────────────────

    /**
     * Process an inbound Razorpay webhook. The org has already been resolved
     * (from the URL path token) and set on TenantContext by the controller.
     * Returns a short status string; NEVER throws out (the controller returns
     * 200 regardless so Razorpay doesn't retry-storm).
     *
     * <p>Layered idempotency: (1) reject a bad HMAC; (2) dedupe by event id;
     * (3) a captured-payment id already recorded → no-op; (4) a link already
     * settled → no-op.
     */
    @Transactional
    public String handleWebhook(UUID orgId, String rawBody, String signatureHeader, String eventId) {
        if (!razorpayClient.verifyWebhookSignature(orgId, rawBody, signatureHeader)) {
            log.warn("Razorpay webhook signature invalid for org {}", orgId);
            return "invalid signature";
        }
        String effectiveEventId = notBlank(eventId) ? eventId.trim()
                : sha(rawBody); // fall back to a body hash when the header is absent
        if (webhookEventRepository.existsByProviderAndEventId(RazorpayClient.PROVIDER, effectiveEventId)) {
            return "duplicate event";
        }

        Map<String, Object> event = parseJson(rawBody);
        String eventType = asString(event.get("event"));
        WebhookPayment wp = extractPayment(event);

        PaymentWebhookEvent logRow = PaymentWebhookEvent.builder()
                .orgId(orgId).provider(RazorpayClient.PROVIDER)
                .eventId(effectiveEventId).eventType(eventType)
                .signatureValid(true).processed(false)
                .build();

        String result;
        try {
            result = applyPayment(orgId, wp, eventType, effectiveEventId, logRow);
        } catch (BusinessException be) {
            // A DETERMINISTIC business failure — retrying won't help. Record the
            // dedupe row and let the controller 200 so Razorpay stops resending.
            log.warn("Razorpay webhook business error for org {} event {}: {}",
                    orgId, effectiveEventId, be.getErrorCode());
            result = "error:" + be.getErrorCode();
        }
        // A NON-business (transient infra) exception is deliberately NOT caught:
        // it propagates, the whole @Transactional rolls back (dedupe row too),
        // and the controller returns 5xx so Razorpay retries — the settlement
        // is never silently lost on a deadlock / lock-timeout.
        webhookEventRepository.save(logRow);
        return result;
    }

    private String applyPayment(UUID orgId, WebhookPayment wp, String eventType,
                                String eventId, PaymentWebhookEvent logRow) {
        // Only settlement events carry a captured payment we can record.
        boolean settlement = eventType != null
                && (eventType.startsWith("payment_link.paid")
                    || eventType.startsWith("payment.captured"));
        if (!settlement || wp == null || (wp.linkId == null && wp.referenceId == null)) {
            return "ignored";
        }

        // (3) captured-payment already recorded anywhere → no-op.
        if (notBlank(wp.paymentId) && paymentLinkRepository
                .findByProviderAndProviderPaymentIdAndIsDeletedFalse(RazorpayClient.PROVIDER, wp.paymentId)
                .isPresent()) {
            return "already recorded";
        }

        PaymentLink resolved = resolveLink(orgId, wp);
        if (resolved == null) {
            return "no matching link";
        }
        // Take a pessimistic write lock on the link before the settled-check +
        // record, so two concurrent settlement events for the same capture
        // serialise: the second blocks here. A locked JPQL re-read would return
        // the STALE first-level-cache instance loaded by resolveLink (Hibernate
        // doesn't re-hydrate an already-managed entity), leaving check (4) dead —
        // entityManager.refresh(..., PESSIMISTIC_WRITE) both takes the row lock
        // AND re-reads committed state, so the second event sees tx1's PAID stamp.
        PaymentLink link = resolved;
        entityManager.refresh(link, LockModeType.PESSIMISTIC_WRITE);
        logRow.setPaymentLinkId(link.getId());

        // (4) this link already settled → no-op.
        if (link.getRecordedPaymentId() != null || "PAID".equals(link.getStatus())) {
            return "link already paid";
        }

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(link.getInvoiceId(), orgId)
                .orElse(null);
        if (invoice == null) {
            return "invoice gone";
        }
        if (!List.of("SENT", "PARTIALLY_PAID", "OVERDUE").contains(invoice.getStatus())) {
            // e.g. already fully paid by a manual receipt — the gateway still
            // captured real money, so flag it for a human (refund / apply as
            // advance) instead of silently swallowing it.
            handleUnattributedCapture(orgId, link, wp, invoice,
                    "invoice already settled (status " + invoice.getStatus() + ")");
            stampPaid(link, wp, eventId, null);
            return "unapplied capture flagged";
        }

        // Never over-collect: clamp to the current outstanding balance. The
        // signed amount is authoritative for the gateway, but our AR ledger is
        // authoritative for how much is still owed.
        BigDecimal amount = wp.amount != null ? wp.amount : link.getAmount();
        BigDecimal balance = invoice.getBalanceDue();
        if (balance == null || balance.signum() <= 0) {
            handleUnattributedCapture(orgId, link, wp, invoice, "nothing due on the invoice");
            stampPaid(link, wp, eventId, null);
            return "unapplied capture flagged";
        }
        if (amount.compareTo(balance) > 0) {
            amount = balance;
        }

        // The webhook runs on a SYSTEM thread with no TenantContext user, but
        // journal_entry.created_by is NOT NULL. Supply the link's creator (a real
        // org user set at link-creation) as the actor so the settlement journal
        // can post; fall back to the org OWNER, else fail deterministically (→
        // caught as BusinessException → 200 + dedupe, no retry storm).
        ensureWebhookActor(orgId, link);

        PaymentResponse pr = paymentService.recordForInvoice(link.getInvoiceId(),
                new RecordPaymentForInvoiceRequest(amount, "BANK_TRANSFER",
                        LocalDate.now(clock),
                        null,
                        notBlank(wp.paymentId) ? wp.paymentId : link.getProviderLinkId(),
                        "Razorpay " + (link.getProviderLinkId() != null ? link.getProviderLinkId() : "")));

        // Money is already collected — if an approval workflow diverted the
        // payment to PENDING_APPROVAL, force-post it so the invoice settles.
        if ("PENDING_APPROVAL".equals(pr.status())) {
            paymentService.postPayment(pr.id());
        }
        stampPaid(link, wp, eventId, pr.id());
        logRow.setProcessed(true);
        return "recorded";
    }

    /**
     * Populate the acting user on TenantContext for the webhook thread so the
     * settlement journal ({@code journal_entry.created_by NOT NULL}) can post.
     * Uses the link's creator, then the org OWNER; a genuinely un-actorable
     * event throws a deterministic BusinessException (caught upstream → 200 +
     * dedupe row, so Razorpay stops resending rather than storming forever).
     */
    private void ensureWebhookActor(UUID orgId, PaymentLink link) {
        if (TenantContext.getCurrentUserId() != null) {
            return;
        }
        if (link.getCreatedBy() != null) {
            TenantContext.setCurrentUserId(link.getCreatedBy());
            return;
        }
        UUID owner = appUserRepository.findFirstByOrgIdAndRoleAndIsDeletedFalse(orgId, "OWNER")
                .map(AppUser::getId).orElse(null);
        if (owner == null) {
            throw new BusinessException(
                    "No actor available to book the gateway settlement (link has no creator and org has no OWNER)",
                    "PAYLINK_NO_ACTOR", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        TenantContext.setCurrentUserId(owner);
    }

    /**
     * A gateway capture that can't be applied to the invoice (already settled /
     * nothing due) is real collected money — raise an idempotent HIGH AI-Inbox
     * suggestion so a human refunds it or applies it as an advance. Idempotent
     * via existsOpenSuggestion (the at-least-once bus sends captured + link.paid).
     */
    private void handleUnattributedCapture(UUID orgId, PaymentLink link, WebhookPayment wp,
                                           Invoice invoice, String reason) {
        boolean exists = aiSuggestionRepository.existsOpenSuggestion(
                orgId, PAYMENT_LINK_ENTITY, link.getId(), null,
                UNAPPLIED_SUGGESTION_TYPE, OPEN_STATUSES);
        if (exists) return;

        Map<String, Object> payload = new HashMap<>();
        payload.put("invoiceNumber", invoice.getInvoiceNumber());
        payload.put("providerPaymentId", wp != null ? wp.paymentId : null);
        payload.put("amount", wp != null && wp.amount != null ? wp.amount : link.getAmount());
        payload.put("reason", reason);

        aiSuggestionService.createSuggestion(AiSuggestion.builder()
                .orgId(orgId)
                .entityType(PAYMENT_LINK_ENTITY)
                .entityId(link.getId())
                .suggestionType(UNAPPLIED_SUGGESTION_TYPE)
                .suggestedAction("REFUND_OR_APPLY_ADVANCE")
                .suggestedValue(payload)
                .priority("HIGH")
                .reasoning("Gateway captured money for invoice " + invoice.getInvoiceNumber()
                        + " but it could not be applied (" + reason
                        + ") — refund the customer or apply it as an advance.")
                .agentName("PaymentLinkService")
                .build());
    }

    private void stampPaid(PaymentLink link, WebhookPayment wp, String eventId, UUID paymentId) {
        link.setStatus("PAID");
        if (wp != null && notBlank(wp.paymentId)) link.setProviderPaymentId(wp.paymentId);
        link.setRecordedPaymentId(paymentId);
        link.setPaidAt(clock.instant());
        link.setLastEventId(eventId);
        paymentLinkRepository.save(link);
    }

    private PaymentLink resolveLink(UUID orgId, WebhookPayment wp) {
        if (wp.linkId != null) {
            PaymentLink byLink = paymentLinkRepository
                    .findByProviderAndProviderLinkIdAndIsDeletedFalse(RazorpayClient.PROVIDER, wp.linkId)
                    .orElse(null);
            if (byLink != null && orgId.equals(byLink.getOrgId())) return byLink;
        }
        if (wp.referenceId != null) {
            return paymentLinkRepository
                    .findFirstByOrgIdAndReferenceIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId, wp.referenceId)
                    .orElse(null);
        }
        return null;
    }

    // ── Razorpay payload extraction ─────────────────────────────────────────

    /** A flat view of the fields we care about, dug out of Razorpay's nested payload. */
    record WebhookPayment(String linkId, String referenceId, String paymentId, BigDecimal amount) {}

    @SuppressWarnings("unchecked")
    private WebhookPayment extractPayment(Map<String, Object> event) {
        Map<String, Object> payload = (Map<String, Object>) event.get("payload");
        if (payload == null) return null;

        String linkId = null, referenceId = null, paymentId = null;
        BigDecimal amount = null;

        Map<String, Object> plink = entity(payload.get("payment_link"));
        if (plink != null) {
            linkId = asString(plink.get("id"));
            referenceId = asString(plink.get("reference_id"));
            if (plink.get("amount_paid") != null) amount = paise(plink.get("amount_paid"));
            else if (plink.get("amount") != null) amount = paise(plink.get("amount"));
        }
        Map<String, Object> pay = entity(payload.get("payment"));
        if (pay != null) {
            paymentId = asString(pay.get("id"));
            if (referenceId == null) referenceId = asString(pay.get("reference_id"));
            if (amount == null && pay.get("amount") != null) amount = paise(pay.get("amount"));
        }
        return new WebhookPayment(linkId, referenceId, paymentId, amount);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> entity(Object node) {
        if (!(node instanceof Map)) return null;
        Map<String, Object> m = (Map<String, Object>) node;
        Object entity = m.get("entity");
        return entity instanceof Map ? (Map<String, Object>) entity : m;
    }

    private static BigDecimal paise(Object v) {
        BigDecimal p = new BigDecimal(v.toString());
        return p.movePointLeft(2);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseJson(String rawBody) {
        try {
            return new com.fasterxml.jackson.databind.ObjectMapper().readValue(rawBody, Map.class);
        } catch (Exception e) {
            return Map.of();
        }
    }

    private static String sha(String s) {
        try {
            var md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] h = md.digest(s.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : h) sb.append(Character.forDigit((b >> 4) & 0xF, 16)).append(Character.forDigit(b & 0xF, 16));
            return sb.substring(0, 40);
        } catch (Exception e) {
            return String.valueOf(s.hashCode());
        }
    }

    private static String asString(Object o) {
        return o == null ? null : o.toString();
    }

    private static String firstNonBlank(String a, String b) {
        return notBlank(a) ? a : (notBlank(b) ? b : null);
    }

    private static boolean notBlank(String v) {
        return v != null && !v.isBlank();
    }
}
