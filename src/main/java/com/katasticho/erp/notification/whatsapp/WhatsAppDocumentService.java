package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.InvoicePdfService;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.pos.dto.SalesReceiptResponse;
import com.katasticho.erp.pos.service.ReceiptPdfService;
import com.katasticho.erp.pos.service.SalesReceiptService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Turns a business document into a WhatsApp send and records the outcome.
 * Resolves the recipient, renders the PDF (invoices/receipts) via the existing
 * PDF services, picks the org's approved template, calls {@link WhatsAppService},
 * and writes a {@link WhatsAppMessage} audit row — SENT, FAILED, or SKIPPED.
 *
 * <p>Never throws for a "can't send" condition (disabled, no number): those are
 * recorded as SKIPPED so callers (incl. the POS auto-send) stay resilient.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WhatsAppDocumentService {

    private final WhatsAppService whatsAppService;
    private final WhatsAppMessageRepository messageRepository;
    private final InvoiceService invoiceService;
    private final InvoicePdfService invoicePdfService;
    private final InvoiceRepository invoiceRepository;
    private final SalesReceiptService salesReceiptService;
    private final ReceiptPdfService receiptPdfService;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final OrgSettingsService orgSettingsService;

    @Transactional
    public WhatsAppMessage sendInvoice(UUID invoiceId) {
        UUID orgId = orgId();
        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
        Contact contact = contact(orgId, invoice.getContactId());
        String phone = phoneOf(contact);
        String template = template(orgId, "whatsapp.template_invoice", "invoice_document");

        if (skip(orgId, phone)) {
            return record("INVOICE", invoiceId, phone, template, skipReason(orgId, phone), null);
        }
        InvoiceResponse resp = invoiceService.getInvoiceResponse(invoiceId);
        byte[] pdf = invoicePdfService.generatePdf(resp);
        List<String> params = List.of(
                nameOf(contact), orgName(orgId), invoice.getInvoiceNumber(), amount(invoice.getTotalAmount()));
        WhatsAppService.SendResult r = whatsAppService.sendTemplate(
                orgId, phone, template, params, pdf, "invoice-" + safe(invoice.getInvoiceNumber()) + ".pdf");
        return record("INVOICE", invoiceId, phone, template, null, r);
    }

    @Transactional
    public WhatsAppMessage sendReceipt(UUID receiptId) {
        UUID orgId = orgId();
        SalesReceiptResponse receipt = salesReceiptService.getById(receiptId);
        Contact contact = receipt.contactId() != null ? contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(receipt.contactId(), orgId).orElse(null) : null;
        String phone = phoneOf(contact);
        String template = template(orgId, "whatsapp.template_receipt", "receipt_document");

        if (skip(orgId, phone)) {
            return record("RECEIPT", receiptId, phone, template, skipReason(orgId, phone), null);
        }
        byte[] pdf = receiptPdfService.generateReceiptPdf(receiptId);
        List<String> params = List.of(
                nameOf(contact), orgName(orgId), receipt.receiptNumber(), amount(receipt.total()));
        WhatsAppService.SendResult r = whatsAppService.sendTemplate(
                orgId, phone, template, params, pdf, "receipt-" + safe(receipt.receiptNumber()) + ".pdf");
        return record("RECEIPT", receiptId, phone, template, null, r);
    }

    /** Payment reminder (no attachment) — template params: name, org, amount. */
    @Transactional
    public WhatsAppMessage sendReminder(UUID contactId) {
        return sendOutstandingNote(contactId, "REMINDER",
                template(orgId(), "whatsapp.template_reminder", "payment_reminder"));
    }

    /** Account statement note (no attachment) — same outstanding figure. */
    @Transactional
    public WhatsAppMessage sendStatement(UUID contactId) {
        return sendOutstandingNote(contactId, "STATEMENT",
                template(orgId(), "whatsapp.template_statement", "account_statement"));
    }

    private WhatsAppMessage sendOutstandingNote(UUID contactId, String docType, String template) {
        UUID orgId = orgId();
        Contact contact = contact(orgId, contactId);
        String phone = phoneOf(contact);
        if (skip(orgId, phone)) {
            return record(docType, contactId, phone, template, skipReason(orgId, phone), null);
        }
        BigDecimal outstanding = invoiceRepository.findOutstandingByContact(orgId, contactId).stream()
                .map(i -> i.getBalanceDue() != null ? i.getBalanceDue() : i.getTotalAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        List<String> params = List.of(nameOf(contact), orgName(orgId), amount(outstanding));
        WhatsAppService.SendResult r = whatsAppService.sendTemplate(orgId, phone, template, params, null, null);
        return record(docType, contactId, phone, template, null, r);
    }

    @Transactional(readOnly = true)
    public List<WhatsAppMessage> recent() {
        return messageRepository.findTop100ByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(orgId());
    }

    /**
     * Fire-and-forget receipt send for the POS hot path, gated by
     * {@code whatsapp.auto_send_receipt}. Dispatched only after the receipt's
     * transaction commits (so the async read sees it) and off the request
     * thread, so checkout is never blocked or failed by a WhatsApp hiccup.
     */
    public void autoSendReceipt(UUID orgId, UUID receiptId) {
        if (!"true".equalsIgnoreCase(orgSettingsService.get(orgId, "whatsapp.auto_send_receipt", "false"))) return;
        if (!whatsAppService.isEnabled(orgId)) return;
        Runnable task = () -> {
            try {
                TenantContext.setCurrentOrgId(orgId);
                sendReceipt(receiptId);
            } catch (Exception e) {
                log.warn("[WhatsApp] auto-send receipt {} failed: {}", receiptId, e.getMessage());
            } finally {
                TenantContext.clear();
            }
        };
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override public void afterCommit() {
                            java.util.concurrent.CompletableFuture.runAsync(task);
                        }
                    });
        } else {
            java.util.concurrent.CompletableFuture.runAsync(task);
        }
    }

    // ── internals ─────────────────────────────────────────────────────────

    private WhatsAppMessage record(String docType, UUID docId, String phone, String template,
                                   String skipReason, WhatsAppService.SendResult result) {
        WhatsAppMessage row = WhatsAppMessage.builder()
                .recipient(phone == null ? "-" : phone)
                .docType(docType)
                .docId(docId)
                .templateName(template)
                .build();
        if (skipReason != null) {
            row.setStatus("SKIPPED");
            row.setErrorMessage(skipReason);
        } else if (result != null && result.ok()) {
            row.setStatus("SENT");
            row.setProvider(result.provider());
            row.setProviderMessageId(result.messageId());
            row.setSentAt(Instant.now());
        } else {
            row.setStatus("FAILED");
            row.setProvider(result != null ? result.provider() : null);
            row.setErrorMessage(result != null ? result.error() : "unknown error");
        }
        return messageRepository.save(row);
    }

    private boolean skip(UUID orgId, String phone) {
        return !whatsAppService.isEnabled(orgId) || phone == null;
    }

    private String skipReason(UUID orgId, String phone) {
        if (!whatsAppService.isEnabled(orgId)) return "WhatsApp not enabled for this org";
        if (phone == null) return "Recipient has no valid WhatsApp number";
        return "Skipped";
    }

    private Contact contact(UUID orgId, UUID contactId) {
        if (contactId == null) {
            throw new BusinessException("Document has no customer to message", "WA_NO_CONTACT");
        }
        return contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
    }

    private String phoneOf(Contact c) {
        if (c == null) return null;
        String raw = c.getMobile() != null && !c.getMobile().isBlank() ? c.getMobile() : c.getPhone();
        return WhatsAppService.toWhatsAppNumber(raw);
    }

    private String nameOf(Contact c) {
        return c != null && c.getDisplayName() != null ? c.getDisplayName() : "Customer";
    }

    private String orgName(UUID orgId) {
        return organisationRepository.findById(orgId).map(Organisation::getName).orElse("Our store");
    }

    private String template(UUID orgId, String key, String fallback) {
        String t = orgSettingsService.get(orgId, key, null);
        return t == null || t.isBlank() ? fallback : t;
    }

    private static String amount(BigDecimal v) {
        return "Rs." + (v == null ? BigDecimal.ZERO : v).setScale(0, java.math.RoundingMode.HALF_UP);
    }

    private static String safe(String s) {
        return s == null ? "doc" : s.replaceAll("[^A-Za-z0-9._-]", "_");
    }

    private UUID orgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        return orgId;
    }
}
