package com.katasticho.erp.payment.service;

import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentForInvoiceRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.PaymentService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.payment.entity.PaymentLink;
import com.katasticho.erp.payment.entity.PaymentWebhookEvent;
import com.katasticho.erp.payment.repository.PaymentLinkRepository;
import com.katasticho.erp.payment.repository.PaymentWebhookEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
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

    private final RazorpayClient razorpayClient;
    private final PaymentLinkRepository paymentLinkRepository;
    private final PaymentWebhookEventRepository webhookEventRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final PaymentService paymentService;
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
        // serialise: the second blocks here, then re-reads a PAID link below.
        PaymentLink link = paymentLinkRepository.findByIdAndIsDeletedFalse(resolved.getId()).orElse(resolved);
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
            // e.g. already fully paid by a manual receipt — nothing to settle.
            stampPaid(link, wp, eventId, null);
            return "invoice not payable";
        }

        // Never over-collect: clamp to the current outstanding balance. The
        // signed amount is authoritative for the gateway, but our AR ledger is
        // authoritative for how much is still owed.
        BigDecimal amount = wp.amount != null ? wp.amount : link.getAmount();
        BigDecimal balance = invoice.getBalanceDue();
        if (balance == null || balance.signum() <= 0) {
            stampPaid(link, wp, eventId, null);
            return "nothing due";
        }
        if (amount.compareTo(balance) > 0) {
            amount = balance;
        }

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
