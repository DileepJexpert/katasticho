package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.StringReader;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class InvoicePdfServiceTest {

    @Mock private DocumentPdfService pdfService;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private OrgSettingsService orgSettingsService;

    @Test
    void buildHtmlProducesXmlParseableXhtml() throws Exception {
        UUID orgId = UUID.randomUUID();
        UUID contactId = UUID.randomUUID();

        Organisation org = Organisation.builder()
                .name("A & B Traders")
                .addressLine1("MG Road & Market Street")
                .city("Bengaluru")
                .state("Karnataka")
                .stateCode("29")
                .gstin("29ABCDE1234F1Z5")
                .phone("9999999999")
                .email("billing@example.com")
                .build();
        org.setId(orgId);

        Contact contact = Contact.builder()
                .displayName("Rajesh & Sons")
                .companyName("Rajesh & Sons")
                .billingAddressLine1("12, Test & Main")
                .billingCity("Bengaluru")
                .billingState("Karnataka")
                .billingStateCode("29")
                .gstin("29ABCDE9999F1Z5")
                .phone("8888888888")
                .email("customer@example.com")
                .build();
        contact.setId(contactId);

        InvoiceResponse invoice = new InvoiceResponse(
                UUID.randomUUID(),
                contactId,
                "Rajesh & Sons",
                "INV-001",
                LocalDate.of(2026, 5, 5),
                LocalDate.of(2026, 5, 12),
                "SENT",
                new BigDecimal("100.00"),
                new BigDecimal("5.00"),
                BigDecimal.ZERO,
                new BigDecimal("105.00"),
                BigDecimal.ZERO,
                new BigDecimal("105.00"),
                "INR",
                "29",
                false,
                UUID.randomUUID(),
                "Handle with care & confirm receipt.",
                "Payment due in 7 days & goods once sold are final.",
                List.of(new InvoiceResponse.LineResponse(
                        UUID.randomUUID(),
                        UUID.randomUUID(),
                        null,
                        null,
                        1,
                        "Tea & Snacks",
                        "0902",
                        BigDecimal.ONE,
                        new BigDecimal("100.00"),
                        BigDecimal.ZERO,
                        BigDecimal.ZERO,
                        new BigDecimal("100.00"),
                        new BigDecimal("5.00"),
                        new BigDecimal("5.00"),
                        new BigDecimal("105.00"),
                        "4120",
                        null,
                        null,
                        null)),
                List.of(new InvoiceResponse.TaxLineResponse(
                        "CGST",
                        new BigDecimal("2.50"),
                        new BigDecimal("100.00"),
                        new BigDecimal("2.50"),
                        "2121")),
                Instant.now());

        when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        when(orgSettingsService.get(orgId, "invoice.default_terms", "")).thenReturn("");
        when(orgSettingsService.get(orgId, "invoice.show_bank_details", "true")).thenReturn("true");
        when(orgSettingsService.get(orgId, "invoice.show_signature", "false")).thenReturn("false");
        when(orgSettingsService.get(orgId, "invoice.bank_name", "")).thenReturn("A&B Bank");
        when(orgSettingsService.get(orgId, "invoice.bank_account_no", "")).thenReturn("12345");
        when(orgSettingsService.get(orgId, "invoice.bank_ifsc", "")).thenReturn("ABCD0001234");
        when(orgSettingsService.get(orgId, "invoice.upi_id", "")).thenReturn("ab@upi");

        InvoicePdfService service = new InvoicePdfService(
                pdfService, organisationRepository, contactRepository, orgSettingsService);

        String html = service.buildHtml(invoice, org);

        DocumentBuilderFactory.newInstance()
                .newDocumentBuilder()
                .parse(new InputSource(new StringReader(html)));
    }
}
