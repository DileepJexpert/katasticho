package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.common.util.AmountToWordsConverter;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class InvoicePdfService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy", Locale.ENGLISH);

    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;
    private final ContactRepository contactRepository;
    private final OrgSettingsService orgSettingsService;

    public byte[] generatePdf(InvoiceResponse inv) {
        Organisation org = organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
        return pdfService.render(buildHtml(inv, org));
    }

    /** Called by email service when org is already loaded, avoiding a redundant organisation lookup. */
    public byte[] generatePdf(InvoiceResponse inv, Organisation org) {
        return pdfService.render(buildHtml(inv, org));
    }

    /** Package-visible: reused by email service to embed HTML in email body. */
    String buildHtml(InvoiceResponse inv, Organisation org) {
        Contact contact = loadContact(inv);
        String terms = firstNonBlank(
                inv.termsAndConditions(),
                orgSettingsService.get(org.getId(), "invoice.default_terms", ""));
        boolean showBankDetails = Boolean.parseBoolean(
                orgSettingsService.get(org.getId(), "invoice.show_bank_details", "true"));
        boolean showSignature = Boolean.parseBoolean(
                orgSettingsService.get(org.getId(), "invoice.show_signature", "false"));
        String bankName = orgSettingsService.get(org.getId(), "invoice.bank_name", "");
        String bankAccountNo = orgSettingsService.get(org.getId(), "invoice.bank_account_no", "");
        String bankIfsc = orgSettingsService.get(org.getId(), "invoice.bank_ifsc", "");
        String upiId = orgSettingsService.get(org.getId(), "invoice.upi_id", "");

        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");

        header(sb, inv, org);
        partiesAndDetails(sb, inv, org, contact);
        lineItems(sb, inv);
        totalsAndTax(sb, inv);
        amountInWords(sb, inv);
        notesTermsPayment(sb, inv, org, terms, showBankDetails, showSignature,
                bankName, bankAccountNo, bankIfsc, upiId);

        sb.append("<div class='footer'>This is a computer generated invoice from Katasticho ERP.</div>");
        sb.append("</body></html>");
        return sb.toString();
    }

    private void header(StringBuilder sb, InvoiceResponse inv, Organisation org) {
        sb.append("<table class='header'><tr>");
        sb.append("<td class='org'>");
        if (notBlank(org.getLogoUrl())) {
            sb.append("<img class='logo' src='").append(esc(org.getLogoUrl())).append("'/>");
        }
        sb.append("<div class='org-name'>").append(esc(org.getName())).append("</div>");
        appendLines(sb, "org-line", orgAddressLines(org));
        appendLabelValue(sb, "org-line", "GSTIN", org.getGstin());
        appendLabelValue(sb, "org-line", "Tax ID", org.getTaxId());
        appendLabelValue(sb, "org-line", "State Code", org.getStateCode());
        appendLabelValue(sb, "org-line", "Phone", org.getPhone());
        appendLabelValue(sb, "org-line", "Email", org.getEmail());
        sb.append("</td>");

        sb.append("<td class='doc-box'>");
        sb.append("<div class='doc-title'>TAX INVOICE</div>");
        sb.append("<div class='doc-subtitle'>Original for Recipient</div>");
        sb.append("<table class='doc-meta'>");
        metaRow(sb, "Invoice No.", inv.invoiceNumber());
        metaRow(sb, "Invoice Date", inv.invoiceDate() != null ? inv.invoiceDate().format(DATE_FMT) : null);
        metaRow(sb, "Due Date", inv.dueDate() != null ? inv.dueDate().format(DATE_FMT) : null);
        metaRow(sb, "Status", label(inv.status()));
        metaRow(sb, "Currency", inv.currency());
        sb.append("</table>");
        sb.append("</td>");
        sb.append("</tr></table>");
    }

    private void partiesAndDetails(StringBuilder sb, InvoiceResponse inv, Organisation org, Contact contact) {
        sb.append("<table class='parties'><tr>");
        sb.append("<td class='party-card'>");
        sb.append("<div class='section-label'>Bill To</div>");
        sb.append("<div class='party-name'>").append(esc(firstNonBlank(
                contact != null ? contact.getCompanyName() : null,
                inv.contactName(),
                "Customer"))).append("</div>");
        appendLines(sb, "party-line", billingAddressLines(contact));
        appendLabelValue(sb, "party-line", "GSTIN", contact != null ? contact.getGstin() : null);
        appendLabelValue(sb, "party-line", "PAN", contact != null ? contact.getPan() : null);
        appendLabelValue(sb, "party-line", "Phone", contact != null ? firstNonBlank(contact.getMobile(), contact.getPhone()) : null);
        appendLabelValue(sb, "party-line", "Email", contact != null ? contact.getEmail() : null);
        sb.append("</td>");

        sb.append("<td class='party-card'>");
        sb.append("<div class='section-label'>Ship To</div>");
        List<String> shipLines = shippingAddressLines(contact);
        if (shipLines.isEmpty()) {
            shipLines = billingAddressLines(contact);
        }
        appendLines(sb, "party-line", shipLines);
        if (shipLines.isEmpty()) {
            sb.append("<div class='muted'>Same as billing address</div>");
        }
        sb.append("</td>");

        sb.append("<td class='supply-card'>");
        sb.append("<div class='section-label'>Tax Details</div>");
        appendInfoRow(sb, "Place of Supply", firstNonBlank(inv.placeOfSupply(), contact != null ? contact.getPlaceOfSupply() : null));
        appendInfoRow(sb, "Reverse Charge", inv.reverseCharge() ? "Yes" : "No");
        appendInfoRow(sb, "Supplier State", stateWithCode(org.getState(), org.getStateCode()));
        appendInfoRow(sb, "Buyer State", contact != null ? stateWithCode(contact.getBillingState(), contact.getBillingStateCode()) : null);
        sb.append("</td>");
        sb.append("</tr></table>");
    }

    private void lineItems(StringBuilder sb, InvoiceResponse inv) {
        sb.append("<table class='items'>");
        sb.append("<thead><tr>");
        sb.append("<th class='c-num'>#</th>");
        sb.append("<th class='c-desc'>Item &amp; Description</th>");
        sb.append("<th class='c-hsn'>HSN/SAC</th>");
        sb.append("<th class='c-qty'>Qty</th>");
        sb.append("<th class='c-rate'>Rate</th>");
        sb.append("<th class='c-disc'>Disc.</th>");
        sb.append("<th class='c-taxable'>Taxable</th>");
        sb.append("<th class='c-tax'>Tax</th>");
        sb.append("<th class='c-total'>Amount</th>");
        sb.append("</tr></thead><tbody>");

        for (InvoiceResponse.LineResponse line : inv.lines()) {
            sb.append("<tr>");
            sb.append("<td class='num'>").append(line.lineNumber()).append("</td>");
            sb.append("<td class='desc'>");
            sb.append("<div class='item-name'>").append(esc(line.description())).append("</div>");
            if (notBlank(line.batchNumber())) {
                sb.append("<div class='item-sub'>Batch: ").append(esc(line.batchNumber()));
                if (notBlank(line.batchExpiry())) {
                    sb.append(" | Exp: ").append(esc(line.batchExpiry()));
                }
                sb.append("</div>");
            }
            sb.append("</td>");
            sb.append("<td class='center'>").append(esc(line.hsnCode())).append("</td>");
            sb.append("<td class='right'>").append(fmtQty(line.quantity())).append("</td>");
            sb.append("<td class='right'>").append(fmtPlain(line.unitPrice())).append("</td>");
            sb.append("<td class='right'>").append(percentOrDash(line.discountPercent())).append("</td>");
            sb.append("<td class='right'>").append(fmtPlain(line.taxableAmount())).append("</td>");
            sb.append("<td class='right'>").append(taxLabel(line)).append("</td>");
            sb.append("<td class='right amount'>").append(fmtPlain(line.lineTotal())).append("</td>");
            sb.append("</tr>");
        }

        sb.append("</tbody></table>");
    }

    private void totalsAndTax(StringBuilder sb, InvoiceResponse inv) {
        sb.append("<table class='summary'><tr>");
        sb.append("<td class='tax-summary'>");
        if (inv.taxLines() != null && !inv.taxLines().isEmpty()) {
            sb.append("<div class='section-label'>Tax Summary</div>");
            sb.append("<table class='tax-table'><thead><tr>");
            sb.append("<th>Component</th><th class='right'>Rate</th><th class='right'>Taxable</th><th class='right'>Tax</th>");
            sb.append("</tr></thead><tbody>");
            for (InvoiceResponse.TaxLineResponse tl : inv.taxLines()) {
                sb.append("<tr>");
                sb.append("<td>").append(esc(tl.componentCode())).append("</td>");
                sb.append("<td class='right'>").append(percent(tl.rate())).append("</td>");
                sb.append("<td class='right'>").append(fmtPlain(tl.taxableAmount())).append("</td>");
                sb.append("<td class='right'>").append(fmtPlain(tl.taxAmount())).append("</td>");
                sb.append("</tr>");
            }
            sb.append("</tbody></table>");
        }
        sb.append("</td>");

        sb.append("<td class='total-box'>");
        sb.append("<table class='total-table'>");
        totalRow(sb, "Subtotal", fmtCurr(inv.subtotal()), false, false);
        totalRow(sb, "Tax", fmtCurr(inv.taxAmount()), false, false);
        totalRow(sb, "Total", fmtCurr(inv.totalAmount()), true, false);
        if (notZero(inv.amountPaid())) {
            totalRow(sb, "Payments Made", fmtCurr(inv.amountPaid()), false, false);
        }
        totalRow(sb, "Balance Due", fmtCurr(inv.balanceDue()), true, true);
        sb.append("</table>");
        sb.append("</td>");
        sb.append("</tr></table>");
    }

    private void amountInWords(StringBuilder sb, InvoiceResponse inv) {
        if (!notZero(inv.totalAmount())) {
            return;
        }
        sb.append("<div class='words'><span class='section-label inline'>Amount in Words: </span>");
        sb.append(esc(AmountToWordsConverter.convert(inv.totalAmount())));
        sb.append("</div>");
    }

    private void notesTermsPayment(StringBuilder sb, InvoiceResponse inv, Organisation org,
                                   String terms, boolean showBankDetails, boolean showSignature,
                                   String bankName, String bankAccountNo, String bankIfsc, String upiId) {
        sb.append("<table class='bottom'><tr>");
        sb.append("<td class='bottom-left'>");
        if (notBlank(inv.notes())) {
            sb.append("<div class='block'><div class='section-label'>Notes</div>");
            sb.append("<div class='block-text'>").append(esc(inv.notes())).append("</div></div>");
        }
        if (notBlank(terms)) {
            sb.append("<div class='block'><div class='section-label'>Terms &amp; Conditions</div>");
            sb.append("<div class='block-text'>").append(esc(terms)).append("</div></div>");
        }
        if (showBankDetails && hasPaymentDetails(bankName, bankAccountNo, bankIfsc, upiId)) {
            sb.append("<div class='block'><div class='section-label'>Payment Details</div>");
            appendLabelValue(sb, "block-text", "Bank", bankName);
            appendLabelValue(sb, "block-text", "Account No.", bankAccountNo);
            appendLabelValue(sb, "block-text", "IFSC", bankIfsc);
            appendLabelValue(sb, "block-text", "UPI", upiId);
            sb.append("</div>");
        }
        sb.append("</td>");

        sb.append("<td class='signature'>");
        if (showSignature) {
            sb.append("<div class='sig-line'></div>");
        }
        sb.append("<div class='sig-title'>Authorized Signatory</div>");
        sb.append("<div class='sig-org'>For ").append(esc(firstNonBlank(org.getName(), "Supplier"))).append("</div>");
        sb.append("</td>");
        sb.append("</tr></table>");
    }

    private Contact loadContact(InvoiceResponse inv) {
        if (inv.contactId() == null) {
            return null;
        }
        return contactRepository.findById(inv.contactId()).orElse(null);
    }

    private List<String> orgAddressLines(Organisation org) {
        List<String> lines = new ArrayList<>();
        addJoined(lines, ", ", org.getAddressLine1(), org.getAddressLine2());
        addJoined(lines, ", ", org.getCity(), org.getState(), org.getPostalCode());
        return lines;
    }

    private List<String> billingAddressLines(Contact contact) {
        List<String> lines = new ArrayList<>();
        if (contact == null) return lines;
        addJoined(lines, ", ", contact.getBillingAddressLine1(), contact.getBillingAddressLine2());
        addJoined(lines, ", ", contact.getBillingCity(), contact.getBillingState(), contact.getBillingPostalCode());
        return lines;
    }

    private List<String> shippingAddressLines(Contact contact) {
        List<String> lines = new ArrayList<>();
        if (contact == null) return lines;
        addJoined(lines, ", ", contact.getShippingAddressLine1(), contact.getShippingAddressLine2());
        addJoined(lines, ", ", contact.getShippingCity(), contact.getShippingState(), contact.getShippingPostalCode());
        return lines;
    }

    private void addJoined(List<String> lines, String separator, String... values) {
        List<String> present = new ArrayList<>();
        for (String value : values) {
            if (notBlank(value)) {
                present.add(value.trim());
            }
        }
        if (!present.isEmpty()) {
            lines.add(String.join(separator, present));
        }
    }

    private void appendLines(StringBuilder sb, String cssClass, List<String> lines) {
        for (String line : lines) {
            sb.append("<div class='").append(cssClass).append("'>").append(esc(line)).append("</div>");
        }
    }

    private void appendLabelValue(StringBuilder sb, String cssClass, String label, String value) {
        if (notBlank(value)) {
            sb.append("<div class='").append(cssClass).append("'><b>")
                    .append(esc(label)).append(":</b> ").append(esc(value)).append("</div>");
        }
    }

    private void appendInfoRow(StringBuilder sb, String label, String value) {
        if (notBlank(value)) {
            sb.append("<div class='info-row'><span>").append(esc(label)).append("</span><b>")
                    .append(esc(value)).append("</b></div>");
        }
    }

    private void metaRow(StringBuilder sb, String label, String value) {
        if (notBlank(value)) {
            sb.append("<tr><td>").append(esc(label)).append("</td><td>").append(esc(value)).append("</td></tr>");
        }
    }

    private void totalRow(StringBuilder sb, String label, String value, boolean bold, boolean highlight) {
        sb.append("<tr class='").append(bold ? "strong" : "").append(highlight ? " highlight" : "").append("'>");
        sb.append("<td>").append(esc(label)).append("</td><td>").append(value).append("</td></tr>");
    }

    private boolean hasPaymentDetails(String bankName, String bankAccountNo, String bankIfsc, String upiId) {
        return notBlank(bankName)
                || notBlank(bankAccountNo)
                || notBlank(bankIfsc)
                || notBlank(upiId);
    }

    private String stateWithCode(String state, String code) {
        if (notBlank(state) && notBlank(code)) return state + " (" + code + ")";
        return firstNonBlank(state, code);
    }

    private String taxLabel(InvoiceResponse.LineResponse line) {
        if (line.gstRate() == null || line.gstRate().compareTo(BigDecimal.ZERO) == 0) {
            return "-";
        }
        return percent(line.gstRate()) + "<br/><span class='item-sub'>" + fmtPlain(line.taxAmount()) + "</span>";
    }

    private String percentOrDash(BigDecimal v) {
        if (v == null || v.compareTo(BigDecimal.ZERO) == 0) return "-";
        return percent(v);
    }

    private String percent(BigDecimal v) {
        if (v == null) return "-";
        return v.stripTrailingZeros().toPlainString() + "%";
    }

    private String fmtCurr(BigDecimal v) {
        return "&#8377;" + fmtPlain(v);
    }

    private String fmtPlain(BigDecimal v) {
        if (v == null) return "0.00";
        return v.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private String fmtQty(BigDecimal v) {
        if (v == null) return "0";
        return v.stripTrailingZeros().toPlainString();
    }

    private boolean notZero(BigDecimal v) {
        return v != null && v.compareTo(BigDecimal.ZERO) > 0;
    }

    private boolean notBlank(String text) {
        return text != null && !text.isBlank();
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (notBlank(value)) {
                return value;
            }
        }
        return "";
    }

    private String label(String text) {
        if (!notBlank(text)) return "";
        return text.replace("_", " ");
    }

    private String esc(String text) {
        if (text == null) return "";
        return text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }

    private String css() {
        return """
                @page { size: A4; margin: 14mm 13mm 17mm 13mm; }
                * { box-sizing: border-box; }
                body { margin: 0; font-family: Arial, Helvetica, sans-serif; font-size: 9.5px; color: #111827; }
                table { border-collapse: collapse; width: 100%; }
                .header { margin-bottom: 12px; border-bottom: 2px solid #111827; }
                .header td { vertical-align: top; padding-bottom: 10px; }
                .org { width: 58%; padding-right: 16px; }
                .logo { max-width: 90px; max-height: 48px; margin-bottom: 6px; }
                .org-name { font-size: 18px; font-weight: 700; color: #111827; margin-bottom: 5px; }
                .org-line, .party-line, .block-text { color: #4B5563; line-height: 1.45; }
                .doc-box { width: 42%; text-align: right; }
                .doc-title { font-size: 26px; font-weight: 800; letter-spacing: 1.2px; color: #0F766E; }
                .doc-subtitle { color: #6B7280; margin: 2px 0 8px; }
                .doc-meta { margin-left: auto; width: 76%; font-size: 9px; }
                .doc-meta td { padding: 2px 0; border-bottom: 1px solid #E5E7EB; }
                .doc-meta td:first-child { color: #6B7280; text-align: left; }
                .doc-meta td:last-child { font-weight: 700; text-align: right; }
                .parties { margin-bottom: 12px; }
                .party-card, .supply-card { width: 33.33%; vertical-align: top; border: 1px solid #E5E7EB; padding: 9px; }
                .party-card + .party-card, .supply-card { border-left: none; }
                .section-label { font-size: 7.5px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; color: #0F766E; margin-bottom: 5px; }
                .section-label.inline { display: inline; margin-right: 4px; }
                .party-name { font-size: 12px; font-weight: 700; margin-bottom: 5px; }
                .muted, .item-sub { color: #6B7280; font-size: 8.5px; }
                .info-row { display: table; width: 100%; line-height: 1.55; color: #4B5563; }
                .info-row span { display: table-cell; width: 48%; }
                .info-row b { display: table-cell; text-align: right; color: #111827; }
                .items { margin-top: 4px; margin-bottom: 12px; border: 1px solid #D1D5DB; }
                .items th { background: #111827; color: #FFFFFF; padding: 7px 6px; font-size: 8px; font-weight: 700; text-align: right; }
                .items td { padding: 7px 6px; border-top: 1px solid #E5E7EB; vertical-align: top; }
                .items tbody tr:nth-child(even) { background: #F9FAFB; }
                .c-num { width: 4%; text-align: center !important; }
                .c-desc { width: 31%; text-align: left !important; }
                .c-hsn { width: 9%; text-align: center !important; }
                .c-qty { width: 7%; }
                .c-rate { width: 10%; }
                .c-disc { width: 8%; }
                .c-taxable { width: 11%; }
                .c-tax { width: 9%; }
                .c-total { width: 11%; }
                .num, .center { text-align: center; }
                .right { text-align: right; }
                .desc { text-align: left; }
                .item-name { font-weight: 700; color: #111827; }
                .amount { font-weight: 700; }
                .summary { margin-top: 6px; margin-bottom: 10px; }
                .tax-summary { width: 58%; vertical-align: top; padding-right: 16px; }
                .tax-table th { background: #F3F4F6; color: #374151; padding: 5px 6px; font-size: 8px; text-align: left; border: 1px solid #E5E7EB; }
                .tax-table td { padding: 5px 6px; border: 1px solid #E5E7EB; color: #374151; }
                .total-box { width: 42%; vertical-align: top; }
                .total-table { border: 1px solid #D1D5DB; }
                .total-table td { padding: 7px 9px; border-bottom: 1px solid #E5E7EB; }
                .total-table td:first-child { color: #4B5563; }
                .total-table td:last-child { text-align: right; font-weight: 700; }
                .total-table tr.strong td { font-size: 11px; color: #111827; }
                .total-table tr.highlight td { background: #ECFDF5; color: #065F46; }
                .words { margin: 10px 0 12px; padding: 8px 10px; background: #F9FAFB; border: 1px solid #E5E7EB; color: #374151; }
                .bottom td { vertical-align: bottom; }
                .bottom-left { width: 62%; padding-right: 18px; }
                .block { margin-top: 10px; }
                .signature { width: 38%; text-align: center; border: 1px solid #E5E7EB; padding: 28px 10px 10px; }
                .sig-line { border-top: 1px solid #111827; margin: 0 20px 8px; }
                .sig-title { font-weight: 700; margin-top: 22px; }
                .sig-org { color: #6B7280; margin-top: 3px; }
                .footer { margin-top: 14px; padding-top: 7px; border-top: 1px solid #E5E7EB; text-align: center; font-size: 7.5px; color: #9CA3AF; }
                """;
    }
}
