package com.katasticho.erp.gst.einvoice;

import org.junit.jupiter.api.Test;
import org.w3c.dom.Document;

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PintAeProviderTest {

    private final PintAeProvider provider = new PintAeProvider();

    private EInvoiceData sample() {
        return new EInvoiceData(
                "INV-2026-001",
                LocalDate.of(2026, 6, 22),
                "AED",
                new EInvoiceData.Party("Al Noor Trading LLC", "100123456700003", "AE"),
                new EInvoiceData.Party("Gulf Buyer & Co", "100987654300003", "AE"),
                List.of(new EInvoiceData.Line("Paracetamol 500mg",
                        new BigDecimal("10"), new BigDecimal("100.00"),
                        new BigDecimal("1000.00"), new BigDecimal("5"))),
                new BigDecimal("1000.00"),
                new BigDecimal("50.00"),
                new BigDecimal("1050.00"),
                new BigDecimal("5"));
    }

    @Test
    void produces_well_formed_xml() {
        String xml = provider.buildPayload(sample());
        assertDoesNotThrow(() -> {
            var f = DocumentBuilderFactory.newInstance();
            f.setNamespaceAware(true);
            Document doc = f.newDocumentBuilder()
                    .parse(new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));
            assertTrue(doc.getDocumentElement().getLocalName().equals("Invoice"));
        });
    }

    @Test
    void carries_mandatory_pint_ae_core() {
        String xml = provider.buildPayload(sample());
        assertEquals_("PINT_AE", provider.providerCode());
        assertTrue(xml.contains("urn:peppol:pint:billing-1@ae-1"), "PINT-AE customization id");
        assertTrue(xml.contains("<cbc:ID>INV-2026-001</cbc:ID>"));
        assertTrue(xml.contains("<cbc:DocumentCurrencyCode>AED</cbc:DocumentCurrencyCode>"));
        assertTrue(xml.contains("<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>"));
        // Supplier + customer TRN under PartyTaxScheme/CompanyID.
        assertTrue(xml.contains("<cbc:CompanyID>100123456700003</cbc:CompanyID>"), "supplier TRN");
        assertTrue(xml.contains("<cbc:CompanyID>100987654300003</cbc:CompanyID>"), "customer TRN");
        assertTrue(xml.contains("Al Noor Trading LLC"));
    }

    @Test
    void single_5pct_vat_category_and_totals() {
        String xml = provider.buildPayload(sample());
        assertTrue(xml.contains("<cbc:Percent>5</cbc:Percent>"), "5% VAT");
        assertTrue(xml.contains("currencyID=\"AED\">50.00</cbc:TaxAmount>"), "VAT amount");
        assertTrue(xml.contains("currencyID=\"AED\">1000.00</cbc:TaxExclusiveAmount>"));
        assertTrue(xml.contains("currencyID=\"AED\">1050.00</cbc:PayableAmount>"));
        // Standard-rate category code S, VAT scheme.
        assertTrue(xml.contains("<cbc:ID>S</cbc:ID>"));
        assertTrue(xml.contains("<cbc:ID>VAT</cbc:ID>"));
    }

    @Test
    void escapes_xml_special_chars_in_party_name() {
        EInvoiceData d = new EInvoiceData("INV-1", LocalDate.of(2026, 6, 22), "AED",
                new EInvoiceData.Party("Smith & Sons <Trading>", "100111111100003", "AE"),
                new EInvoiceData.Party("Buyer", "100222222200003", "AE"),
                List.of(), BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, new BigDecimal("5"));
        String xml = provider.buildPayload(d);
        assertTrue(xml.contains("Smith &amp; Sons &lt;Trading&gt;"), "escaped");
        // Still parses.
        assertDoesNotThrow(() -> {
            var f = DocumentBuilderFactory.newInstance();
            f.setNamespaceAware(true);
            f.newDocumentBuilder().parse(
                    new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));
        });
    }

    private static void assertEquals_(String exp, String act) {
        org.junit.jupiter.api.Assertions.assertEquals(exp, act);
    }
}
