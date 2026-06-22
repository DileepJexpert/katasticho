package com.katasticho.erp.gst.einvoice;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * UAE PINT-AE e-invoice generator — produces Peppol BIS Billing 3.0 / PINT-AE
 * UBL 2.1 XML, the structured format the FTA's 2027 mandate requires (submitted
 * via an Accredited Service Provider, which we integrate rather than build).
 *
 * <p>This is the demo-prop / foundation stub: it emits valid-shaped UBL with the
 * mandatory core (CustomizationID/ProfileID, supplier+customer TRN, currency,
 * tax totals with a single 5% VAT category, monetary totals, lines). It is NOT
 * routed to an ASP — that is Phase 2. Reusing the existing GspClient transport
 * for submission comes later; this proves we can produce a compliant document.
 */
@Component
public class PintAeProvider implements EInvoiceProvider {

    /** PINT-AE customization identifier (UAE Peppol PINT). */
    private static final String CUSTOMIZATION_ID = "urn:peppol:pint:billing-1@ae-1";
    private static final String PROFILE_ID = "urn:peppol:bis:billing";
    private static final String VAT = "VAT";
    /** UNCL5305 tax category code: S = standard rate. */
    private static final String STANDARD_RATE = "S";
    /** UNCL1001 document type code: 380 = commercial invoice. */
    private static final String INVOICE_TYPE = "380";

    @Override
    public String providerCode() {
        return "PINT_AE";
    }

    @Override
    public String buildPayload(EInvoiceData d) {
        String cur = d.currencyCode();
        StringBuilder b = new StringBuilder(2048);
        b.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        b.append("<Invoice xmlns=\"urn:oasis:names:specification:ubl:schema:xsd:Invoice-2\"")
                .append(" xmlns:cac=\"urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2\"")
                .append(" xmlns:cbc=\"urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2\">\n");
        el(b, "cbc:CustomizationID", CUSTOMIZATION_ID);
        el(b, "cbc:ProfileID", PROFILE_ID);
        el(b, "cbc:ID", d.invoiceNumber());
        el(b, "cbc:IssueDate", d.issueDate() == null ? "" : d.issueDate().toString());
        el(b, "cbc:InvoiceTypeCode", INVOICE_TYPE);
        el(b, "cbc:DocumentCurrencyCode", cur);

        party(b, "cac:AccountingSupplierParty", d.supplier());
        party(b, "cac:AccountingCustomerParty", d.customer());

        // Tax total (single standard-rate VAT subtotal).
        b.append("  <cac:TaxTotal>\n");
        amt(b, "    ", "cbc:TaxAmount", cur, d.taxTotal());
        b.append("    <cac:TaxSubtotal>\n");
        amt(b, "      ", "cbc:TaxableAmount", cur, d.taxableTotal());
        amt(b, "      ", "cbc:TaxAmount", cur, d.taxTotal());
        b.append("      <cac:TaxCategory>\n");
        el2(b, "        ", "cbc:ID", STANDARD_RATE);
        el2(b, "        ", "cbc:Percent", plain(d.vatRatePercent()));
        b.append("        <cac:TaxScheme>\n");
        el2(b, "          ", "cbc:ID", VAT);
        b.append("        </cac:TaxScheme>\n");
        b.append("      </cac:TaxCategory>\n");
        b.append("    </cac:TaxSubtotal>\n");
        b.append("  </cac:TaxTotal>\n");

        // Monetary totals.
        b.append("  <cac:LegalMonetaryTotal>\n");
        amt(b, "    ", "cbc:LineExtensionAmount", cur, d.taxableTotal());
        amt(b, "    ", "cbc:TaxExclusiveAmount", cur, d.taxableTotal());
        amt(b, "    ", "cbc:TaxInclusiveAmount", cur, d.grandTotal());
        amt(b, "    ", "cbc:PayableAmount", cur, d.grandTotal());
        b.append("  </cac:LegalMonetaryTotal>\n");

        // Lines.
        int i = 1;
        if (d.lines() != null) {
            for (EInvoiceData.Line line : d.lines()) {
                b.append("  <cac:InvoiceLine>\n");
                el2(b, "    ", "cbc:ID", String.valueOf(i++));
                amtUnit(b, "    ", "cbc:InvoicedQuantity", line.quantity());
                amt(b, "    ", "cbc:LineExtensionAmount", cur, line.lineNet());
                b.append("    <cac:Item>\n");
                el2(b, "      ", "cbc:Name", esc(line.description()));
                b.append("      <cac:ClassifiedTaxCategory>\n");
                el2(b, "        ", "cbc:ID", STANDARD_RATE);
                el2(b, "        ", "cbc:Percent", plain(line.vatRatePercent()));
                b.append("        <cac:TaxScheme>\n");
                el2(b, "          ", "cbc:ID", VAT);
                b.append("        </cac:TaxScheme>\n");
                b.append("      </cac:ClassifiedTaxCategory>\n");
                b.append("    </cac:Item>\n");
                b.append("    <cac:Price>\n");
                amt(b, "      ", "cbc:PriceAmount", cur, line.unitPrice());
                b.append("    </cac:Price>\n");
                b.append("  </cac:InvoiceLine>\n");
            }
        }

        b.append("</Invoice>\n");
        return b.toString();
    }

    // ── helpers ──────────────────────────────────────────────────────

    private void party(StringBuilder b, String wrapper, EInvoiceData.Party p) {
        b.append("  <").append(wrapper).append(">\n");
        b.append("    <cac:Party>\n");
        if (p != null && p.taxId() != null && !p.taxId().isBlank()) {
            b.append("      <cac:PartyTaxScheme>\n");
            el2(b, "        ", "cbc:CompanyID", esc(p.taxId()));
            b.append("        <cac:TaxScheme>\n");
            el2(b, "          ", "cbc:ID", VAT);
            b.append("        </cac:TaxScheme>\n");
            b.append("      </cac:PartyTaxScheme>\n");
        }
        b.append("      <cac:PartyLegalEntity>\n");
        el2(b, "        ", "cbc:RegistrationName", esc(p == null ? "" : p.name()));
        b.append("      </cac:PartyLegalEntity>\n");
        b.append("    </cac:Party>\n");
        b.append("  </").append(wrapper).append(">\n");
    }

    private void el(StringBuilder b, String tag, String val) {
        el2(b, "  ", tag, esc(val));
    }

    private void el2(StringBuilder b, String indent, String tag, String val) {
        b.append(indent).append('<').append(tag).append('>')
                .append(val == null ? "" : val).append("</").append(tag).append(">\n");
    }

    private void amt(StringBuilder b, String indent, String tag, String cur, BigDecimal v) {
        b.append(indent).append('<').append(tag).append(" currencyID=\"").append(cur).append("\">")
                .append(money(v)).append("</").append(tag).append(">\n");
    }

    private void amtUnit(StringBuilder b, String indent, String tag, BigDecimal v) {
        b.append(indent).append('<').append(tag).append(" unitCode=\"EA\">")
                .append(plain(v)).append("</").append(tag).append(">\n");
    }

    private String money(BigDecimal v) {
        return (v == null ? BigDecimal.ZERO : v).setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private String plain(BigDecimal v) {
        return (v == null ? BigDecimal.ZERO : v).stripTrailingZeros().toPlainString();
    }

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
