package com.katasticho.erp.gst.service;

import com.katasticho.erp.ai.entity.AiSuggestion;
import com.katasticho.erp.ai.service.AiSuggestionService;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.gst.entity.EInvoice;
import com.katasticho.erp.gst.repository.EInvoiceRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EInvoiceServiceTest {

    private final EInvoiceRepository eInvoiceRepository = mock(EInvoiceRepository.class);
    private final InvoiceRepository invoiceRepository = mock(InvoiceRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final OrganisationRepository organisationRepository = mock(OrganisationRepository.class);
    private final OrgSettingsService orgSettingsService = mock(OrgSettingsService.class);
    private final AiSuggestionService aiSuggestionService = mock(AiSuggestionService.class);

    private final EInvoiceService service = new EInvoiceService(
            eInvoiceRepository, invoiceRepository, contactRepository,
            organisationRepository, orgSettingsService, aiSuggestionService);

    private final UUID orgId = UUID.randomUUID();
    private final UUID invoiceId = UUID.randomUUID();
    private final UUID buyerId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(orgSettingsService.get(eq(orgId), eq(EInvoiceService.ENABLED_SETTING), any()))
                .thenReturn("true");
        when(organisationRepository.findById(orgId)).thenReturn(Optional.empty());
        when(eInvoiceRepository.save(any(EInvoice.class))).thenAnswer(inv -> {
            EInvoice e = inv.getArgument(0);
            if (e.getId() == null) e.setId(UUID.randomUUID());
            return e;
        });
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void postedB2bInvoiceCreatesPendingEntryAndSuggestion() {
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice()));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(buyerId, orgId))
                .thenReturn(Optional.of(registeredBuyer()));
        when(eInvoiceRepository.existsByOrgIdAndInvoiceIdAndIsDeletedFalse(orgId, invoiceId))
                .thenReturn(false);

        service.detectForInvoice(orgId, invoiceId);

        verify(eInvoiceRepository).save(any(EInvoice.class));
        verify(aiSuggestionService).createSuggestion(any(AiSuggestion.class));
    }

    @Test
    void disabledOrgIsIgnored() {
        when(orgSettingsService.get(eq(orgId), eq(EInvoiceService.ENABLED_SETTING), any()))
                .thenReturn("false");

        service.detectForInvoice(orgId, invoiceId);

        verify(eInvoiceRepository, never()).save(any());
    }

    @Test
    void b2cInvoiceWithoutGstinIsIgnored() {
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice()));
        Contact walkIn = Contact.builder()
                .contactType(ContactType.CUSTOMER).displayName("Walk-in").build();
        walkIn.setId(buyerId);
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(buyerId, orgId))
                .thenReturn(Optional.of(walkIn));

        service.detectForInvoice(orgId, invoiceId);

        verify(eInvoiceRepository, never()).save(any());
    }

    @Test
    void duplicateDetectionIsSkipped() {
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice()));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(buyerId, orgId))
                .thenReturn(Optional.of(registeredBuyer()));
        when(eInvoiceRepository.existsByOrgIdAndInvoiceIdAndIsDeletedFalse(orgId, invoiceId))
                .thenReturn(true);

        service.detectForInvoice(orgId, invoiceId);

        verify(eInvoiceRepository, never()).save(any());
    }

    @Test
    void recordGeneratedStoresIrnAndQr() {
        UUID id = UUID.randomUUID();
        EInvoice pending = EInvoice.builder()
                .invoiceId(invoiceId).documentNumber("INV-9")
                .documentDate(LocalDate.of(2026, 6, 1))
                .totalValue(new BigDecimal("118000")).build();
        pending.setId(id);
        pending.setOrgId(orgId);
        when(eInvoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(pending));

        EInvoice updated = service.recordGenerated(
                id, "a1b2c3d4e5", "112010012345678", "2026-06-10 11:30:00", "signed.qr.payload");

        assertThat(updated.getStatus()).isEqualTo("GENERATED");
        assertThat(updated.getIrn()).isEqualTo("a1b2c3d4e5");
        assertThat(updated.getAckNumber()).isEqualTo("112010012345678");
        assertThat(updated.getSignedQr()).isEqualTo("signed.qr.payload");
        assertThat(updated.getGeneratedAt()).isNotNull();
    }

    @Test
    @SuppressWarnings("unchecked")
    void portalJsonBuildsIrpInv01Shape() {
        Invoice invoice = invoice();
        invoice.getLines().add(InvoiceLine.builder()
                .invoice(invoice).lineNumber(1).description("Crocin 500mg")
                .hsnCode("3004").quantity(new BigDecimal("100"))
                .unitPrice(new BigDecimal("500"))
                .taxableAmount(new BigDecimal("50000")).gstRate(new BigDecimal("12"))
                .taxAmount(new BigDecimal("6000")).lineTotal(new BigDecimal("56000"))
                .itemId(UUID.randomUUID())
                .build());
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(invoice));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(buyerId, orgId))
                .thenReturn(Optional.of(registeredBuyer()));

        UUID id = UUID.randomUUID();
        EInvoice row = EInvoice.builder()
                .invoiceId(invoiceId).documentNumber("INV-9")
                .documentDate(LocalDate.of(2026, 6, 1))
                .totalValue(new BigDecimal("56000")).build();
        row.setId(id);
        row.setOrgId(orgId);
        when(eInvoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(row));

        Map<String, Object> json = service.portalJson(id);

        assertThat(json.get("Version")).isEqualTo("1.1");
        Map<String, Object> doc = (Map<String, Object>) json.get("DocDtls");
        assertThat(doc.get("No")).isEqualTo("INV-9");
        Map<String, Object> buyer = (Map<String, Object>) json.get("BuyerDtls");
        assertThat(buyer.get("Gstin")).isEqualTo("27AABCT1234A1Z5");
        Map<String, Object> val = (Map<String, Object>) json.get("ValDtls");
        assertThat((BigDecimal) val.get("AssVal")).isEqualByComparingTo("50000");
        // Buyer state matches seller default ("") → buyer "27" differs → IGST? Seller
        // state is blank (no org), so the split falls back to intra-state CGST/SGST.
        assertThat(((java.util.List<Map<String, Object>>) json.get("ItemList"))).hasSize(1);
    }

    private Invoice invoice() {
        return Invoice.builder()
                .id(invoiceId)
                .orgId(orgId)
                .invoiceNumber("INV-9")
                .invoiceDate(LocalDate.of(2026, 6, 1))
                .contactId(buyerId)
                .status("SENT")
                .totalAmount(new BigDecimal("56000"))
                .placeOfSupply("27")
                .build();
    }

    private Contact registeredBuyer() {
        Contact c = Contact.builder()
                .contactType(ContactType.CUSTOMER)
                .displayName("MediMart Distributors")
                .gstin("27AABCT1234A1Z5")
                .billingStateCode("27")
                .build();
        c.setId(buyerId);
        return c;
    }
}
