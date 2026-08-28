package com.katasticho.erp.notification.whatsapp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.organisation.OrgSetting;
import com.katasticho.erp.organisation.OrgSettingsRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.payment.entity.PaymentLink;
import com.katasticho.erp.payment.service.PaymentLinkService;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

/**
 * Automated conversational WhatsApp Bot for customer service, instant ledger & balance inquiries,
 * UPI payment link generation, and unstructured message-to-Sales-Order drafting.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WhatsAppBotService {

    private final WhatsAppService whatsAppService;
    private final WhatsAppDocumentService documentService;
    private final WhatsAppOrderService orderService;
    private final WhatsAppMessageRepository messageRepository;
    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;
    private final PaymentLinkService paymentLinkService;
    private final OrganisationRepository organisationRepository;
    private final OrgSettingsRepository orgSettingsRepository;
    private final OrgSettingsService orgSettingsService;
    private final ObjectMapper objectMapper;

    public record BotReply(
            String replyText,
            String intent,
            String actionTaken,
            String status,
            UUID relatedDocId,
            String docType
    ) {}

    /**
     * Inbound message processing pipeline.
     */
    @Transactional
    public BotReply handleIncomingMessage(UUID orgId, String fromPhone, String messageText) {
        String cleanPhone = WhatsAppService.toWhatsAppNumber(fromPhone);
        String last10 = cleanPhone != null && cleanPhone.length() >= 10
                ? cleanPhone.substring(cleanPhone.length() - 10)
                : fromPhone;

        Contact contact = contactRepository.findByOrgIdAndPhoneMatch(orgId, fromPhone, last10).orElse(null);
        String contactName = contact != null ? contact.getDisplayName() : "Valued Customer";
        String orgName = organisationRepository.findById(orgId).map(Organisation::getName).orElse("Katasticho ERP");

        // Record Inbound Audit Log
        WhatsAppMessage inMsg = WhatsAppMessage.builder()
                .recipient(fromPhone)
                .docType("BOT_INBOUND")
                .direction("INBOUND")
                .status("RECEIVED")
                .body(messageText)
                .sentAt(Instant.now())
                .build();
        inMsg.setOrgId(orgId);
        messageRepository.save(inMsg);

        String trimmed = messageText != null ? messageText.trim() : "";
        String upper = trimmed.toUpperCase(Locale.ROOT);

        BotReply reply;

        if (isGreetingOrMenu(upper)) {
            reply = buildMenuReply(contactName, orgName);
        } else if (isBalanceQuery(upper)) {
            reply = buildBalanceReply(orgId, contact, contactName, orgName);
        } else if (isStatementQuery(upper)) {
            reply = buildStatementReply(orgId, contact, contactName, orgName);
        } else if (isPaymentQuery(upper)) {
            reply = buildPaymentReply(orgId, contact, contactName, orgName);
        } else if (isOrderQuery(upper, trimmed)) {
            reply = buildOrderReply(orgId, contact, contactName, trimmed);
        } else {
            // Check if message parses as product items
            reply = tryParseOrderOrFallback(orgId, contact, contactName, orgName, trimmed);
        }

        // Send text reply to customer
        WhatsAppService.SendResult sendResult = whatsAppService.sendTextMessage(orgId, fromPhone, reply.replyText());

        // Record Outbound Bot Reply Audit Log
        WhatsAppMessage outMsg = WhatsAppMessage.builder()
                .recipient(fromPhone)
                .docType(reply.docType() != null ? reply.docType() : "BOT_REPLY")
                .docId(reply.relatedDocId())
                .direction("OUTBOUND")
                .status(sendResult.ok() ? "SENT" : "FAILED")
                .provider(sendResult.provider())
                .providerMessageId(sendResult.messageId())
                .errorMessage(sendResult.error())
                .body(reply.replyText())
                .sentAt(Instant.now())
                .build();
        outMsg.setOrgId(orgId);
        messageRepository.save(outMsg);

        return reply;
    }

    private boolean isGreetingOrMenu(String text) {
        return text.equals("HI") || text.equals("HELLO") || text.equals("HEY") ||
                text.equals("MENU") || text.equals("HELP") || text.equals("START") ||
                text.equals("NAMASTE") || text.equals("OPTIONS");
    }

    private boolean isBalanceQuery(String text) {
        return text.equals("1") || text.contains("BALANCE") || text.contains("INVOICE") ||
                text.contains("OUTSTANDING") || text.contains("HISAB") || text.contains("DUES") ||
                text.contains("BILL");
    }

    private boolean isStatementQuery(String text) {
        return text.equals("2") || text.contains("STATEMENT") || text.contains("LEDGER") ||
                text.contains("KHATA") || text.contains("PASSBOOK");
    }

    private boolean isPaymentQuery(String text) {
        return text.equals("3") || text.contains("PAY") || text.contains("PAYMENT") ||
                text.contains("UPI") || text.contains("QR") || text.contains("LINK");
    }

    private boolean isOrderQuery(String upper, String raw) {
        return upper.equals("4") || upper.startsWith("ORDER ") || upper.startsWith("ORDER:") ||
                upper.contains("BHEJ DO") || upper.contains("BHEJO") || upper.contains("CHAHIYE");
    }

    private BotReply buildMenuReply(String contactName, String orgName) {
        String msg = String.format(
                "👋 Hello *%s*, welcome to *%s*!\n\n" +
                "How can we help you today? Reply with a number or keyword:\n\n" +
                "1️⃣ *Balance & Invoices* — View pending balance & unpaid bills\n" +
                "2️⃣ *Account Statement* — Get your ledger summary\n" +
                "3️⃣ *Pay Now (UPI / Card)* — Instant payment link\n" +
                "4️⃣ *Place Order* — e.g. 'ORDER 10 Crocin 650, 5 Dolo 500'\n\n" +
                "_Powered by Katasticho ERP_",
                contactName, orgName
        );
        return new BotReply(msg, "MENU", "MENU_DISPLAYED", "COMPLETED", null, "BOT_MENU");
    }

    private BotReply buildBalanceReply(UUID orgId, Contact contact, String contactName, String orgName) {
        if (contact == null) {
            String msg = "⚠️ We could not find an account linked to this phone number with " + orgName + ". Please contact support.";
            return new BotReply(msg, "BALANCE", "CONTACT_NOT_FOUND", "SKIPPED", null, "BOT_BALANCE");
        }

        List<Invoice> unpaid = invoiceRepository.findOutstandingByContact(orgId, contact.getId());
        BigDecimal totalDue = unpaid.stream()
                .map(i -> i.getBalanceDue() != null ? i.getBalanceDue() : i.getTotalAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (totalDue.compareTo(BigDecimal.ZERO) <= 0 || unpaid.isEmpty()) {
            String msg = String.format("🎉 Great news, *%s*! You have *zero outstanding dues* with *%s*.\n\nReply *4* to place a new order!", contactName, orgName);
            return new BotReply(msg, "BALANCE", "ZERO_BALANCE", "COMPLETED", null, "BOT_BALANCE");
        }

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("📊 *Outstanding Balance Summary for %s*:\n", contactName));
        sb.append(String.format("Total Due: *₹%,.2f* across %d pending invoice(s):\n\n", totalDue, unpaid.size()));

        int count = 0;
        for (Invoice inv : unpaid) {
            if (count++ >= 3) break;
            BigDecimal bal = inv.getBalanceDue() != null ? inv.getBalanceDue() : inv.getTotalAmount();
            sb.append(String.format("• *%s*: ₹%,.2f (Due: %s)\n",
                    inv.getInvoiceNumber(), bal, inv.getDueDate() != null ? inv.getDueDate().toString() : "Immediate"));
        }

        if (unpaid.size() > 3) {
            sb.append(String.format("_+ %d more invoices_\n", unpaid.size() - 3));
        }

        sb.append("\n👉 Reply *3* to receive an instant online payment link or UPI QR.");

        return new BotReply(sb.toString(), "BALANCE", "BALANCE_FETCHED", "COMPLETED", null, "BOT_BALANCE");
    }

    private BotReply buildStatementReply(UUID orgId, Contact contact, String contactName, String orgName) {
        if (contact == null) {
            String msg = "⚠️ No account found for this number with " + orgName + ".";
            return new BotReply(msg, "STATEMENT", "CONTACT_NOT_FOUND", "SKIPPED", null, "BOT_STATEMENT");
        }

        List<Invoice> unpaid = invoiceRepository.findOutstandingByContact(orgId, contact.getId());
        BigDecimal totalDue = unpaid.stream()
                .map(i -> i.getBalanceDue() != null ? i.getBalanceDue() : i.getTotalAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        String msg = String.format(
                "📜 *Account Statement Summary*\n" +
                "Account: *%s*\n" +
                "Organization: *%s*\n" +
                "Current Outstanding: *₹%,.2f*\n" +
                "Active Unpaid Invoices: *%d*\n\n" +
                "Your detailed statement has been processed. Reply *1* for bill list or *3* to pay.",
                contactName, orgName, totalDue, unpaid.size()
        );

        return new BotReply(msg, "STATEMENT", "STATEMENT_SENT", "COMPLETED", contact.getId(), "BOT_STATEMENT");
    }

    private BotReply buildPaymentReply(UUID orgId, Contact contact, String contactName, String orgName) {
        if (contact == null) {
            String msg = "⚠️ No account found for this number.";
            return new BotReply(msg, "PAYMENT", "CONTACT_NOT_FOUND", "SKIPPED", null, "BOT_PAYMENT");
        }

        List<Invoice> unpaid = invoiceRepository.findOutstandingByContact(orgId, contact.getId());
        if (unpaid.isEmpty()) {
            String msg = String.format("🎉 *%s*, you have no pending dues with *%s*! No payment required.", contactName, orgName);
            return new BotReply(msg, "PAYMENT", "NO_DUES", "COMPLETED", null, "BOT_PAYMENT");
        }

        Invoice latest = unpaid.get(0);
        BigDecimal amount = latest.getBalanceDue() != null ? latest.getBalanceDue() : latest.getTotalAmount();

        String paymentUrl = null;
        try {
            PaymentLink link = paymentLinkService.createForInvoice(latest.getId());
            paymentUrl = link.getShortUrl();
        } catch (Exception e) {
            log.warn("[WhatsAppBot] Payment link creation fallback: {}", e.getMessage());
        }

        String upiVpa = orgSettingsService.get(orgId, "payouts.upi_vpa", "billing@katasticho");

        StringBuilder sb = new StringBuilder();
        sb.append(String.format("💳 *Instant Payment Gateway Link for %s*:\n\n", contactName));
        sb.append(String.format("Invoice: *%s*\n", latest.getInvoiceNumber()));
        sb.append(String.format("Amount: *₹%,.2f*\n\n", amount));

        if (paymentUrl != null && !paymentUrl.isBlank()) {
            sb.append(String.format("🔗 *Click to Pay (Cards/NetBanking/UPI)*:\n%s\n\n", paymentUrl));
        }

        sb.append(String.format("📲 *Direct UPI VPA*: `%s`\n", upiVpa));
        sb.append("After payment, your invoice and ledger will reconcile automatically!");

        return new BotReply(sb.toString(), "PAYMENT", "PAYMENT_LINK_GENERATED", "COMPLETED", latest.getId(), "BOT_PAYMENT");
    }

    private BotReply buildOrderReply(UUID orgId, Contact contact, String contactName, String rawMessage) {
        if (contact == null) {
            String msg = "⚠️ To place an order, your phone number must be registered with the distributor.";
            return new BotReply(msg, "ORDER", "CONTACT_NOT_FOUND", "SKIPPED", null, "BOT_ORDER");
        }

        String orderText = rawMessage.replaceFirst("(?i)^ORDER[:\\s]*", "").trim();
        if (orderText.isBlank()) {
            String msg = "📝 Please specify items and quantities to order. Example:\n*ORDER 10 Crocin 650, 5 Dolo 500, 2 Amul 1L*";
            return new BotReply(msg, "ORDER", "EMPTY_ORDER_PROMPT", "PROMPT", null, "BOT_ORDER");
        }

        var parsed = orderService.parseForContact(orderText, contact.getId());
        if (parsed.matchedCount() == 0) {
            String msg = String.format("⚠️ We could not match any catalog items from '%s'.\nPlease check product names or reply *MENU*.", orderText);
            return new BotReply(msg, "ORDER", "NO_ITEMS_MATCHED", "FAILED", null, "BOT_ORDER");
        }

        SalesOrderResponse so = orderService.confirmAndCreate(parsed, contact.getId(), "WHATSAPP-BOT");

        StringBuilder sb = new StringBuilder();
        sb.append("✅ *Order Created Successfully!* 📦\n\n");
        sb.append(String.format("Order Number: *%s*\n", so.salesOrderNumber()));
        sb.append(String.format("Customer: *%s*\n", contactName));
        sb.append(String.format("Matched Items: *%d / %d*\n", parsed.matchedCount(), parsed.lineCount()));
        sb.append(String.format("Estimated Total: *₹%,.2f*\n", parsed.estimatedTotal()));
        sb.append("Status: *DRAFT (Sent for Warehouse Dispatch)*\n\n");

        for (var line : parsed.lines()) {
            if (line.matched()) {
                sb.append(String.format("• %s × %s — ₹%,.2f\n",
                        line.itemName(), line.quantity().stripTrailingZeros().toPlainString(),
                        line.salePrice().multiply(line.quantity())));
            }
        }

        sb.append("\nOur fulfillment team has received your order and will dispatch shortly!");

        return new BotReply(sb.toString(), "ORDER", "ORDER_CREATED", "COMPLETED", so.id(), "SALES_ORDER");
    }

    private BotReply tryParseOrderOrFallback(UUID orgId, Contact contact, String contactName, String orgName, String rawMessage) {
        if (contact != null) {
            var parsed = orderService.parseForContact(rawMessage, contact.getId());
            if (parsed.matchedCount() > 0) {
                SalesOrderResponse so = orderService.confirmAndCreate(parsed, contact.getId(), "WHATSAPP-BOT");
                String msg = String.format(
                        "✅ *Order Created from Message!* 📦\n" +
                        "Order No: *%s*\n" +
                        "Items: *%d*\n" +
                        "Estimated Total: *₹%,.2f*\n\n" +
                        "Dispatch is being prepared. Reply *1* to check balance.",
                        so.salesOrderNumber(), parsed.matchedCount(), parsed.estimatedTotal()
                );
                return new BotReply(msg, "ORDER", "ORDER_CREATED", "COMPLETED", so.id(), "SALES_ORDER");
            }
        }

        String msg = String.format(
                "🤖 I didn't quite understand that. Here is what I can do for you:\n\n" +
                "1️⃣ *Balance & Invoices*\n" +
                "2️⃣ *Account Statement*\n" +
                "3️⃣ *Payment Link*\n" +
                "4️⃣ *Place Order (e.g. 'ORDER 10 Crocin')*\n\n" +
                "Reply with a number (1-4) or type *MENU*."
        );
        return new BotReply(msg, "FALLBACK", "FALLBACK_TRIGGERED", "COMPLETED", null, "BOT_FALLBACK");
    }

    /**
     * Interactive Simulator Endpoint for UI Testing.
     */
    @Transactional
    public BotReply simulate(UUID orgId, UUID contactId, String messageText, String overridePhone) {
        TenantContext.setCurrentOrgId(orgId);
        String phone = overridePhone;
        if ((phone == null || phone.isBlank()) && contactId != null) {
            Contact c = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId).orElse(null);
            if (c != null) {
                phone = c.getPhone() != null ? c.getPhone() : c.getMobile();
            }
        }
        if (phone == null || phone.isBlank()) {
            phone = "919876543210";
        }
        return handleIncomingMessage(orgId, phone, messageText);
    }

    /**
     * Ensure a per-org webhook token exists and return it.
     */
    public String ensureWebhookToken(UUID orgId) {
        String token = orgSettingsService.get(orgId, "whatsapp.webhook_token", null);
        if (token == null || token.isBlank()) {
            token = "whk_" + UUID.randomUUID().toString().replace("-", "");
            orgSettingsService.set(orgId, "whatsapp.webhook_token", token);
        }
        return token;
    }

    /**
     * Webhook Handshake Verification for Meta Cloud API.
     */
    public boolean verifyWebhookHandshake(String token, String mode, String verifyToken, String challenge) {
        if (!"subscribe".equals(mode) || challenge == null || challenge.isBlank()) {
            return false;
        }
        UUID orgId = resolveOrgByWebhookToken(token).orElse(null);
        if (orgId == null) {
            log.warn("[WhatsApp Webhook] Handshake failed: unknown token {}", token);
            return false;
        }

        String expectedVerifyToken = orgSettingsService.get(orgId, "whatsapp.verify_token", null);
        if (expectedVerifyToken == null || expectedVerifyToken.isBlank()) {
            expectedVerifyToken = token;
        }

        boolean matched = verifyToken != null && verifyToken.equals(expectedVerifyToken);
        if (!matched) {
            log.warn("[WhatsApp Webhook] Verify token mismatch for org {}", orgId);
        }
        return matched;
    }

    /**
     * Webhook ingestion for Meta & Custom WhatsApp Gateways with HMAC-SHA256 signature verification.
     */
    @Transactional
    public boolean processInboundWebhook(String token, String rawBody, String signatureHeader) {
        UUID orgId = resolveOrgByWebhookToken(token).orElse(null);
        if (orgId == null) {
            log.warn("[WhatsApp Webhook] Unknown or invalid webhook token: {}", token);
            return false;
        }

        // Validate HMAC signature if app secret is configured
        String appSecret = orgSettingsService.get(orgId, "whatsapp.app_secret", null);
        if (appSecret != null && !appSecret.isBlank()) {
            if (signatureHeader == null || signatureHeader.isBlank()) {
                log.warn("[WhatsApp Webhook] Missing X-Hub-Signature-256 header for org {}", orgId);
                return false;
            }
            if (!verifyHubSignature(rawBody, signatureHeader, appSecret.trim())) {
                log.warn("[WhatsApp Webhook] Invalid X-Hub-Signature-256 signature for org {}", orgId);
                return false;
            }
        }

        try {
            TenantContext.setCurrentOrgId(orgId);
            JsonNode root = objectMapper.readTree(rawBody);

            // Meta Cloud API Webhook Format
            JsonNode entry = root.path("entry");
            if (entry.isArray() && !entry.isEmpty()) {
                JsonNode changes = entry.get(0).path("changes");
                if (changes.isArray() && !changes.isEmpty()) {
                    JsonNode val = changes.get(0).path("value");
                    JsonNode msgs = val.path("messages");
                    if (msgs.isArray() && !msgs.isEmpty()) {
                        JsonNode m = msgs.get(0);
                        String from = m.path("from").asText();
                        String text = m.path("text").path("body").asText();
                        if (from != null && !from.isBlank() && text != null && !text.isBlank()) {
                            handleIncomingMessage(orgId, from, text);
                            return true;
                        }
                    }
                }
            }

            // Flat Webhook Format (Custom Aggregators / Gupshup)
            String from = root.path("from").asText(null);
            if (from == null) from = root.path("sender").asText(null);
            String text = root.path("message").asText(null);
            if (text == null) text = root.path("text").asText(null);

            if (from != null && !from.isBlank() && text != null && !text.isBlank()) {
                handleIncomingMessage(orgId, from, text);
                return true;
            }

            return true;
        } catch (Exception e) {
            log.error("[WhatsApp Webhook] Error processing webhook for org {}: {}", orgId, e.getMessage(), e);
            return false;
        } finally {
            TenantContext.clear();
        }
    }

    private boolean verifyHubSignature(String payload, String signatureHeader, String appSecret) {
        try {
            String sig = signatureHeader.trim();
            if (sig.startsWith("sha256=")) {
                sig = sig.substring(7);
            }
            javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(
                    appSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(payload.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            String computed = sb.toString();
            return java.security.MessageDigest.isEqual(
                    computed.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                    sig.toLowerCase().getBytes(java.nio.charset.StandardCharsets.UTF_8));
        } catch (Exception e) {
            log.warn("[WhatsApp Webhook] Signature calculation error: {}", e.getMessage());
            return false;
        }
    }

    public Optional<UUID> resolveOrgByWebhookToken(String token) {
        if (token == null || token.isBlank()) return Optional.empty();
        return orgSettingsRepository.findFirstByKeyAndValue("whatsapp.webhook_token", token.trim())
                .map(OrgSetting::getOrgId);
    }
}
