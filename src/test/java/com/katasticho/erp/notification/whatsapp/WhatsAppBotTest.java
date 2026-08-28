package com.katasticho.erp.notification.whatsapp;

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
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class WhatsAppBotTest {

    @Mock private WhatsAppService whatsAppService;
    @Mock private WhatsAppDocumentService documentService;
    @Mock private WhatsAppOrderService orderService;
    @Mock private WhatsAppMessageRepository messageRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private InvoiceRepository invoiceRepository;
    @Mock private PaymentLinkService paymentLinkService;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private OrgSettingsRepository orgSettingsRepository;
    @Mock private OrgSettingsService orgSettingsService;

    private WhatsAppBotService botService;
    private final UUID orgId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();
    private Contact mockContact;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        botService = new WhatsAppBotService(
                whatsAppService, documentService, orderService, messageRepository,
                contactRepository, invoiceRepository, paymentLinkService,
                organisationRepository, orgSettingsRepository, orgSettingsService, new ObjectMapper()
        );

        mockContact = Contact.builder()
                .displayName("MedPlus Chemist")
                .phone("919876543210")
                .build();
        mockContact.setId(contactId);
        mockContact.setOrgId(orgId);

        when(contactRepository.findByOrgIdAndPhoneMatch(eq(orgId), anyString(), anyString()))
                .thenReturn(Optional.of(mockContact));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(eq(contactId), eq(orgId)))
                .thenReturn(Optional.of(mockContact));

        Organisation org = Organisation.builder().name("Apex Pharmaceuticals").build();
        org.setId(orgId);
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        when(whatsAppService.sendTextMessage(any(), any(), any()))
                .thenReturn(WhatsAppService.SendResult.ok("META", "wamid_12345"));
        when(orgSettingsService.get(eq(orgId), anyString(), anyString()))
                .thenAnswer(inv -> inv.getArgument(2));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void testMenuCommand_ReturnsGreetingAndOptions() {
        var reply = botService.handleIncomingMessage(orgId, "919876543210", "MENU");

        assertNotNull(reply);
        assertEquals("MENU", reply.intent());
        assertTrue(reply.replyText().contains("MedPlus Chemist"));
        assertTrue(reply.replyText().contains("Apex Pharmaceuticals"));
        assertTrue(reply.replyText().contains("1️⃣ *Balance & Invoices*"));
        assertTrue(reply.replyText().contains("4️⃣ *Place Order*"));
        verify(messageRepository, times(2)).save(any(WhatsAppMessage.class)); // 1 inbound + 1 outbound
    }

    @Test
    void testBalanceCommand_WithOutstandingInvoices() {
        Invoice inv1 = Invoice.builder()
                .invoiceNumber("INV-2026-001")
                .totalAmount(new BigDecimal("15000.00"))
                .balanceDue(new BigDecimal("15000.00"))
                .dueDate(LocalDate.of(2026, 8, 25))
                .build();
        inv1.setId(UUID.randomUUID());
        inv1.setOrgId(orgId);

        when(invoiceRepository.findOutstandingByContact(orgId, contactId))
                .thenReturn(List.of(inv1));

        var reply = botService.handleIncomingMessage(orgId, "919876543210", "BALANCE");

        assertNotNull(reply);
        assertEquals("BALANCE", reply.intent());
        assertTrue(reply.replyText().contains("15,000.00"));
        assertTrue(reply.replyText().contains("INV-2026-001"));
        assertTrue(reply.replyText().contains("Reply *3* to receive an instant online payment link"));
    }

    @Test
    void testPaymentCommand_GeneratesPaymentLink() {
        Invoice inv1 = Invoice.builder()
                .invoiceNumber("INV-2026-002")
                .totalAmount(new BigDecimal("8500.00"))
                .balanceDue(new BigDecimal("8500.00"))
                .build();
        inv1.setId(UUID.randomUUID());
        inv1.setOrgId(orgId);

        when(invoiceRepository.findOutstandingByContact(orgId, contactId))
                .thenReturn(List.of(inv1));

        PaymentLink link = PaymentLink.builder()
                .shortUrl("https://rzp.io/i/test1234")
                .build();
        link.setId(UUID.randomUUID());
        when(paymentLinkService.createForInvoice(inv1.getId())).thenReturn(link);

        var reply = botService.handleIncomingMessage(orgId, "919876543210", "PAY");

        assertNotNull(reply);
        assertEquals("PAYMENT", reply.intent());
        assertTrue(reply.replyText().contains("https://rzp.io/i/test1234"));
        assertTrue(reply.replyText().contains("INV-2026-002"));
    }

    @Test
    void testOrderCommand_ParsesAndCreatesDraftSalesOrder() {
        UUID itemId = UUID.randomUUID();
        WhatsAppOrderService.ParsedLine line = new WhatsAppOrderService.ParsedLine(
                "10 crocin 650", "crocin 650", new BigDecimal("10"), "strip",
                true, itemId, "Crocin 650mg Tablet", new BigDecimal("32.50"), 0.95, List.of()
        );

        WhatsAppOrderService.ParsedOrder parsed = new WhatsAppOrderService.ParsedOrder(
                "10 crocin 650", 1, 1, new BigDecimal("325.00"), List.of(line), List.of()
        );

        when(orderService.parseForContact("10 crocin 650", contactId)).thenReturn(parsed);

        SalesOrderResponse soResp = mock(SalesOrderResponse.class);
        when(soResp.id()).thenReturn(UUID.randomUUID());
        when(soResp.salesOrderNumber()).thenReturn("SO-2026-901");
        when(orderService.confirmAndCreate(eq(parsed), eq(contactId), anyString())).thenReturn(soResp);

        var reply = botService.handleIncomingMessage(orgId, "919876543210", "ORDER 10 crocin 650");

        assertNotNull(reply);
        assertEquals("ORDER", reply.intent());
        assertTrue(reply.replyText().contains("SO-2026-901"));
        assertTrue(reply.replyText().contains("Crocin 650mg Tablet"));
        assertTrue(reply.replyText().contains("325.00"));
    }

    @Test
    void testVerifyWebhookHandshake_ValidToken_ReturnsTrue() {
        String token = "whk_test_secret_123";
        OrgSetting setting = OrgSetting.builder().orgId(orgId).key("whatsapp.webhook_token").value(token).build();
        when(orgSettingsRepository.findFirstByKeyAndValue("whatsapp.webhook_token", token))
                .thenReturn(Optional.of(setting));
        when(orgSettingsService.get(orgId, "whatsapp.verify_token", null)).thenReturn("my_verify_secret");

        boolean ok = botService.verifyWebhookHandshake(token, "subscribe", "my_verify_secret", "challenge_123");
        assertTrue(ok);

        boolean badMode = botService.verifyWebhookHandshake(token, "publish", "my_verify_secret", "challenge_123");
        assertFalse(badMode);

        boolean badToken = botService.verifyWebhookHandshake(token, "subscribe", "wrong_token", "challenge_123");
        assertFalse(badToken);
    }

    @Test
    void testWebhookIngestion_ResolvesOrgAndProcessesMessage() {
        String token = "whk_test_secret_123";
        OrgSetting setting = OrgSetting.builder().orgId(orgId).key("whatsapp.webhook_token").value(token).build();
        when(orgSettingsRepository.findFirstByKeyAndValue("whatsapp.webhook_token", token))
                .thenReturn(Optional.of(setting));

        String rawJson = "{\"from\":\"919876543210\",\"message\":\"HI\"}";

        boolean ok = botService.processInboundWebhook(token, rawJson, null);
        assertTrue(ok);
        verify(whatsAppService).sendTextMessage(eq(orgId), eq("919876543210"), contains("Apex Pharmaceuticals"));
    }

    @Test
    void testWebhookIngestion_WithHmacSignature() {
        String token = "whk_test_secret_123";
        OrgSetting setting = OrgSetting.builder().orgId(orgId).key("whatsapp.webhook_token").value(token).build();
        when(orgSettingsRepository.findFirstByKeyAndValue("whatsapp.webhook_token", token))
                .thenReturn(Optional.of(setting));
        when(orgSettingsService.get(orgId, "whatsapp.app_secret", null)).thenReturn("test_app_secret");

        String rawJson = "{\"from\":\"919876543210\",\"message\":\"HI\"}";

        // Missing signature when secret configured -> reject
        boolean rejectedMissing = botService.processInboundWebhook(token, rawJson, null);
        assertFalse(rejectedMissing);

        // Invalid signature -> reject
        boolean rejectedInvalid = botService.processInboundWebhook(token, rawJson, "sha256=invalidhex123");
        assertFalse(rejectedInvalid);
    }
}
