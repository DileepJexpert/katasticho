package com.katasticho.erp.notification.whatsapp;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.service.InvoicePdfService;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.service.ReceiptPdfService;
import com.katasticho.erp.pos.service.SalesReceiptService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link WhatsAppDocumentService} — the orchestration contract:
 * disabled / no-number attempts are recorded SKIPPED without calling the
 * provider, and a successful send records SENT with the right template + params.
 */
class WhatsAppDocumentServiceTest {

    private final WhatsAppService whatsAppService = mock(WhatsAppService.class);
    private final WhatsAppMessageRepository messageRepository = mock(WhatsAppMessageRepository.class);
    private final InvoiceService invoiceService = mock(InvoiceService.class);
    private final InvoicePdfService invoicePdfService = mock(InvoicePdfService.class);
    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final SalesReceiptService salesReceiptService = mock(SalesReceiptService.class);
    private final ReceiptPdfService receiptPdfService = mock(ReceiptPdfService.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final OrganisationRepository organisationRepository = mock(OrganisationRepository.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);

    private final WhatsAppDocumentService service = new WhatsAppDocumentService(
            whatsAppService, messageRepository, invoiceService, invoicePdfService, invoiceRepository,
            salesReceiptService, receiptPdfService, contactRepository, organisationRepository, orgSettingsService);

    private final UUID orgId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(messageRepository.save(any(WhatsAppMessage.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void sendReminder_whenDisabled_recordsSkippedAndDoesNotCallProvider() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(customer("Sharma Stores", "9876543210")));
        when(whatsAppService.isEnabled(orgId)).thenReturn(false);

        WhatsAppMessage row = service.sendReminder(contactId);

        assertThat(row.getStatus()).isEqualTo("SKIPPED");
        assertThat(row.getErrorMessage()).contains("not enabled");
        verify(whatsAppService, never()).sendTemplate(any(), any(), any(), anyList(), any(), any());
    }

    @Test
    void sendReminder_whenEnabled_sendsWithThreeParamsAndRecordsSent() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(customer("Sharma Stores", "9876543210")));
        when(whatsAppService.isEnabled(orgId)).thenReturn(true);
        when(orgSettingsService.get(eq(orgId), eq("whatsapp.template_reminder"), any())).thenReturn("payment_reminder");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.empty());
        Invoice inv = Invoice.builder().orgId(orgId).contactId(contactId)
                .balanceDue(new BigDecimal("1500")).totalAmount(new BigDecimal("1500")).build();
        when(invoiceRepository.findOutstandingByContact(orgId, contactId)).thenReturn(List.of(inv));
        when(whatsAppService.sendTemplate(eq(orgId), eq("919876543210"), eq("payment_reminder"),
                anyList(), eq(null), eq(null)))
                .thenReturn(WhatsAppService.SendResult.ok("META", "wamid.123"));

        WhatsAppMessage row = service.sendReminder(contactId);

        assertThat(row.getStatus()).isEqualTo("SENT");
        assertThat(row.getProviderMessageId()).isEqualTo("wamid.123");
        assertThat(row.getRecipient()).isEqualTo("919876543210");
        verify(whatsAppService).sendTemplate(eq(orgId), eq("919876543210"), eq("payment_reminder"),
                argThat(p -> p.size() == 3 && p.get(2).contains("1500")), eq(null), eq(null));
    }

    @Test
    void sendReminder_whenContactHasNoNumber_recordsSkipped() {
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(customer("No Phone Co", null)));
        when(whatsAppService.isEnabled(orgId)).thenReturn(true);

        WhatsAppMessage row = service.sendReminder(contactId);

        assertThat(row.getStatus()).isEqualTo("SKIPPED");
        assertThat(row.getErrorMessage()).contains("no valid WhatsApp number");
        verify(whatsAppService, never()).sendTemplate(any(), any(), any(), anyList(), any(), any());
    }

    private Contact customer(String name, String mobile) {
        Contact c = Contact.builder()
                .contactType(ContactType.CUSTOMER)
                .displayName(name)
                .mobile(mobile)
                .build();
        c.setId(contactId);
        c.setOrgId(orgId);
        return c;
    }
}
