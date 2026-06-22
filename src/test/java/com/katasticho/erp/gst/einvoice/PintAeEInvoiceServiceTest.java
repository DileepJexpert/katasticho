package com.katasticho.erp.gst.einvoice;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.InvoiceLine;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PintAeEInvoiceServiceTest {

    @Mock private InvoiceRepository invoiceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private ContactRepository contactRepository;
    private PintAeEInvoiceService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID invoiceId = UUID.randomUUID();
    private final UUID contactId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PintAeEInvoiceService(
                invoiceRepository, organisationRepository, contactRepository, new PintAeProvider());
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    private void stubFullInvoice() {
        InvoiceLine line = InvoiceLine.builder()
                .description("Paracetamol 500mg")
                .quantity(new BigDecimal("10"))
                .unitPrice(new BigDecimal("100.00"))
                .gstRate(new BigDecimal("5"))
                .lineTotal(new BigDecimal("1000.00"))
                .build();
        Invoice inv = Invoice.builder()
                .invoiceNumber("INV-2026-009")
                .invoiceDate(LocalDate.of(2026, 6, 22))
                .currency("AED")
                .contactId(contactId)
                .subtotal(new BigDecimal("1000.00"))
                .taxAmount(new BigDecimal("50.00"))
                .totalAmount(new BigDecimal("1050.00"))
                .lines(List.of(line))
                .build();
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.of(inv));

        Organisation org = Organisation.builder()
                .name("Al Noor Trading LLC").countryCode("AE")
                .taxId("100123456700003").build();
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        Contact buyer = Contact.builder()
                .displayName("Gulf Buyer").companyName("Gulf Buyer & Co")
                .taxId("100987654300003").build();
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(buyer));
    }

    @Test
    void maps_invoice_org_and_contact_into_einvoice_data() {
        stubFullInvoice();
        EInvoiceData d = service.toData(invoiceId);

        assertEquals("INV-2026-009", d.invoiceNumber());
        assertEquals("AED", d.currencyCode());
        assertEquals("Al Noor Trading LLC", d.supplier().name());
        assertEquals("100123456700003", d.supplier().taxId());     // org.taxId
        assertEquals("Gulf Buyer & Co", d.customer().name());      // contact.companyName preferred
        assertEquals("100987654300003", d.customer().taxId());
        assertEquals(1, d.lines().size());
        assertEquals(new BigDecimal("5"), d.vatRatePercent());     // from line gstRate
        assertEquals(new BigDecimal("1000.00"), d.taxableTotal());
        assertEquals(new BigDecimal("50.00"), d.taxTotal());
        assertEquals(new BigDecimal("1050.00"), d.grandTotal());
    }

    @Test
    void generates_pint_ae_xml_end_to_end() {
        stubFullInvoice();
        String xml = service.generateXml(invoiceId);
        assertTrue(xml.contains("urn:peppol:pint:billing-1@ae-1"));
        assertTrue(xml.contains("<cbc:ID>INV-2026-009</cbc:ID>"));
        assertTrue(xml.contains("100123456700003"));               // supplier TRN
        assertTrue(xml.contains("<cbc:Percent>5</cbc:Percent>"));
    }

    @Test
    void unknown_invoice_throws_not_found() {
        when(invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId))
                .thenReturn(Optional.empty());
        assertThrows(BusinessException.class, () -> service.toData(invoiceId));
    }
}
