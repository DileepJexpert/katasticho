package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.CreditNoteResponse;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.common.util.AmountToWordsConverter;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class CreditNotePdfService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy");

    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;

    public byte[] generatePdf(CreditNoteResponse cn) {
        Organisation org = organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
        return pdfService.render(buildHtml(cn, org));
    }

    String buildHtml(CreditNoteResponse cn, Organisation org) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");

        // ── Header: org (left) | CREDIT NOTE (right) ─────────────────────────
        sb.append("<table width='100%' class='hdr'><tr>");
        sb.append("<td class='org-cell'>");
        sb.append("<div class='org-name'>").append(esc(org.getName())).append("</div>");
        orgAddress(sb, org);
        sb.append("</td>");
        sb.append("<td class='inv-title-cell'>");
        sb.append("<div class='inv-title'>CREDIT NOTE</div>");
        sb.append("<div class='inv-number'>").append(esc(cn.creditNoteNumber())).append("</div>");
        sb.append("<div class='inv-status ").append(statusClass(cn.status())).append("'>")
                .append(esc(cn.status().replace("_", " "))).append("</div>");
        sb.append("</td></tr></table>");

        sb.append("<hr class='divider'/>");

        // ── Meta: customer (left) | dates (right) ────────────────────────────
        sb.append("<table width='100%' class='meta'><tr>");
        sb.append("<td class='bill-to-cell'>");
        sb.append("<div class='lbl'>CREDIT TO</div>");
        sb.append("<div class='contact-name'>").append(esc(cn.contactName())).append("</div>");
        if (cn.invoiceNumber() != null && !cn.invoiceNumber().isBlank()) {
            sb.append("<div class='ref'>Against Invoice: ").append(esc(cn.invoiceNumber())).append("</div>");
        }
        sb.append("</td>");
        sb.append("<td class='dates-cell'>");
        if (cn.creditNoteDate() != null) {
            dateLine(sb, "Date", cn.creditNoteDate().format(DATE_FMT));
        }
        if (cn.placeOfSupply() != null && !cn.placeOfSupply().isBlank()) {
            dateLine(sb, "Place of Supply", cn.placeOfSupply());
        }
        sb.append("</td></tr></table>");

        // ── Reason ────────────────────────────────────────────────────────────
        if (cn.reason() != null && !cn.reason().isBlank()) {
            sb.append("<div class='reason-box'>");
            sb.append("<span class='lbl'>REASON: </span>");
            sb.append("<span class='reason-text'>").append(esc(cn.reason())).append("</span>");
            sb.append("</div>");
        }

        // ── Line items table ──────────────────────────────────────────────────
        sb.append("<table class='items'>");
        sb.append("<thead><tr>");
        sb.append("<th class='th-desc'>Description</th>");
        sb.append("<th class='th-hsn'>HSN/SAC</th>");
        sb.append("<th class='th-num'>Qty</th>");
        sb.append("<th class='th-num'>Rate (&#8377;)</th>");
        sb.append("<th class='th-num'>GST%</th>");
        sb.append("<th class='th-num'>Amount (&#8377;)</th>");
        sb.append("</tr></thead><tbody>");

        Map<String, BigDecimal[]> taxByRate = new LinkedHashMap<>();

        boolean odd = true;
        for (CreditNoteResponse.LineResponse line : cn.lines()) {
            sb.append("<tr class='").append(odd ? "row-odd" : "row-even").append("'>");
            sb.append("<td class='td-left'>").append(esc(line.description())).append("</td>");
            sb.append("<td class='td-center'>").append(line.hsnCode() != null ? esc(line.hsnCode()) : "").append("</td>");
            sb.append("<td class='td-right'>").append(fmtQty(line.quantity())).append("</td>");
            sb.append("<td class='td-right'>").append(fmtPlain(line.unitPrice())).append("</td>");
            sb.append("<td class='td-right'>")
                    .append(line.gstRate() != null ? line.gstRate().stripTrailingZeros().toPlainString() + "%" : "")
                    .append("</td>");
            sb.append("<td class='td-right'>").append(fmtPlain(line.lineTotal())).append("</td>");
            sb.append("</tr>");
            odd = !odd;

            if (line.gstRate() != null && notZero(line.taxAmount())) {
                String rateKey = line.gstRate().stripTrailingZeros().toPlainString() + "%";
                taxByRate.computeIfAbsent(rateKey, k -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO});
                BigDecimal taxable = line.taxableAmount() != null ? line.taxableAmount() : line.lineTotal();
                taxByRate.get(rateKey)[0] = taxByRate.get(rateKey)[0].add(taxable);
                taxByRate.get(rateKey)[1] = taxByRate.get(rateKey)[1].add(line.taxAmount());
            }
        }
        sb.append("</tbody></table>");

        // ── Totals + Tax breakdown ────────────────────────────────────────────
        sb.append("<table width='100%' class='totals-outer'><tr>");

        sb.append("<td class='tax-cell'>");
        if (!taxByRate.isEmpty()) {
            sb.append("<div class='lbl'>TAX SUMMARY</div>");
            sb.append("<table class='tax-tbl'><thead><tr>");
            sb.append("<th class='tax-th-left'>GST Rate</th>");
            sb.append("<th class='tax-th-right'>Taxable (&#8377;)</th>");
            sb.append("<th class='tax-th-right'>Tax (&#8377;)</th>");
            sb.append("</tr></thead><tbody>");
            for (Map.Entry<String, BigDecimal[]> e : taxByRate.entrySet()) {
                sb.append("<tr>");
                sb.append("<td class='td-left'>").append(esc(e.getKey())).append("</td>");
                sb.append("<td class='td-right'>").append(fmtPlain(e.getValue()[0])).append("</td>");
                sb.append("<td class='td-right'>").append(fmtPlain(e.getValue()[1])).append("</td>");
                sb.append("</tr>");
            }
            sb.append("</tbody></table>");
        }
        sb.append("</td>");

        sb.append("<td class='totals-cell'>");
        sb.append("<table class='totals-tbl'>");
        totalRow(sb, "Subtotal", fmtCurr(cn.subtotal()), false);
        if (notZero(cn.taxAmount())) {
            totalRow(sb, "Tax", fmtCurr(cn.taxAmount()), false);
        }
        sb.append("<tr><td colspan='2'><hr class='totals-hr'/></td></tr>");
        totalRow(sb, "Credit Total", fmtCurr(cn.totalAmount()), true);
        sb.append("</table>");
        sb.append("</td></tr></table>");

        // ── Amount in words ───────────────────────────────────────────────────
        if (notZero(cn.totalAmount())) {
            sb.append("<div class='words'>");
            sb.append("<span class='lbl'>AMOUNT IN WORDS: </span>");
            sb.append("<span class='words-text'>").append(AmountToWordsConverter.convert(cn.totalAmount())).append("</span>");
            sb.append("</div>");
        }

        sb.append("<div class='footer'>Powered by Katasticho</div>");
        sb.append("</body></html>");
        return sb.toString();
    }

    private void orgAddress(StringBuilder sb, Organisation org) {
        if (org.getAddressLine1() != null) {
            sb.append("<div class='org-sub'>").append(esc(org.getAddressLine1()));
            if (org.getCity() != null) sb.append(", ").append(esc(org.getCity()));
            if (org.getState() != null) sb.append(", ").append(esc(org.getState()));
            sb.append("</div>");
        }
        if (org.getGstin() != null) {
            sb.append("<div class='org-sub'>GSTIN: ").append(esc(org.getGstin())).append("</div>");
        }
        if (org.getPhone() != null) {
            sb.append("<div class='org-sub'>").append(esc(org.getPhone())).append("</div>");
        }
        if (org.getEmail() != null) {
            sb.append("<div class='org-sub'>").append(esc(org.getEmail())).append("</div>");
        }
    }

    private void dateLine(StringBuilder sb, String label, String value) {
        sb.append("<div class='date-row'><span class='date-lbl'>").append(label)
                .append(":</span> ").append(esc(value)).append("</div>");
    }

    private void totalRow(StringBuilder sb, String label, String value, boolean bold) {
        sb.append("<tr>");
        sb.append("<td class='totals-lbl'>").append(bold ? "<b>" + label + "</b>" : label).append("</td>");
        sb.append("<td class='totals-val'>").append(bold ? "<b>" + value + "</b>" : value).append("</td>");
        sb.append("</tr>");
    }

    private String css() {
        return """
                @page { size: A4; margin: 15mm 15mm 20mm 15mm; }
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: Arial, Helvetica, sans-serif; font-size: 10px; color: #0F172A; }
                .hdr td { vertical-align: top; padding-bottom: 10px; }
                .org-cell { width: 60%; }
                .org-name { font-size: 17px; font-weight: bold; color: #2563EB; margin-bottom: 4px; }
                .org-sub { font-size: 9px; color: #64748B; line-height: 1.6; }
                .inv-title-cell { width: 40%; text-align: right; }
                .inv-title { font-size: 24px; font-weight: bold; color: #DC2626; letter-spacing: 2px; }
                .inv-number { font-size: 13px; font-weight: bold; color: #0F172A; margin-top: 2px; }
                .inv-status { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 8px; font-weight: bold; margin-top: 5px; }
                .status-draft { background: #F1F5F9; color: #64748B; }
                .status-issued { background: #D1FAE5; color: #065F46; }
                .status-applied { background: #DBEAFE; color: #1D4ED8; }
                .status-cancelled { background: #F1F5F9; color: #94A3B8; }
                .divider { border: none; border-top: 1.5px solid #E2E8F0; margin: 8px 0 12px; }
                .meta td { vertical-align: top; padding-bottom: 14px; }
                .bill-to-cell { width: 55%; }
                .dates-cell { width: 45%; text-align: right; }
                .lbl { font-size: 7.5px; font-weight: bold; color: #94A3B8; letter-spacing: 1.5px; margin-bottom: 4px; text-transform: uppercase; }
                .contact-name { font-size: 13px; font-weight: bold; color: #0F172A; }
                .ref { font-size: 9px; color: #64748B; margin-top: 3px; }
                .reason-box { margin-bottom: 12px; padding: 6px 10px; background: #FEF3C7; border-radius: 4px; }
                .reason-text { font-size: 9.5px; color: #92400E; }
                .date-row { font-size: 9px; line-height: 1.9; }
                .date-lbl { color: #64748B; }
                .items { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 9.5px; }
                .items thead tr { background: #DC2626; color: white; }
                .items thead th { padding: 7px 8px; text-align: right; font-size: 8px; font-weight: bold; letter-spacing: 0.4px; }
                .th-desc { text-align: left !important; width: 38%; }
                .th-hsn { text-align: center !important; width: 11%; }
                .th-num { width: 10%; }
                .row-odd { background: #FEF2F2; }
                .row-even { background: #FFFFFF; }
                .items tbody td { padding: 6px 8px; border-bottom: 1px solid #FEE2E2; }
                .td-left { text-align: left; }
                .td-center { text-align: center; color: #64748B; }
                .td-right { text-align: right; }
                .totals-outer td { vertical-align: top; padding-top: 4px; }
                .tax-cell { width: 52%; padding-right: 12px; }
                .tax-tbl { width: 100%; border-collapse: collapse; font-size: 9px; }
                .tax-tbl thead tr { background: #F1F5F9; }
                .tax-th-left { padding: 4px 6px; text-align: left; font-size: 7.5px; }
                .tax-th-right { padding: 4px 6px; text-align: right; font-size: 7.5px; }
                .tax-tbl tbody td { padding: 3px 6px; border-bottom: 1px solid #F1F5F9; }
                .totals-cell { width: 48%; text-align: right; }
                .totals-tbl { width: 100%; border-collapse: collapse; font-size: 10px; }
                .totals-lbl { padding: 3px 0; text-align: left; color: #475569; }
                .totals-val { padding: 3px 0; text-align: right; }
                .totals-hr { border: none; border-top: 1.5px solid #E2E8F0; margin: 4px 0; }
                .words { margin-top: 12px; padding: 6px 10px; background: #F8FAFC; border-radius: 4px; }
                .words-text { font-size: 9.5px; color: #334155; font-style: italic; }
                .notes { margin-top: 16px; margin-bottom: 12px; }
                .notes-text { font-size: 9.5px; color: #475569; line-height: 1.6; margin-top: 4px; }
                .footer { text-align: center; font-size: 7.5px; color: #CBD5E1; margin-top: 20px; padding-top: 8px; border-top: 1px solid #E2E8F0; }
                """;
    }

    private String statusClass(String status) {
        return switch (status.toUpperCase()) {
            case "ISSUED" -> "status-issued";
            case "APPLIED" -> "status-applied";
            case "CANCELLED" -> "status-cancelled";
            default -> "status-draft";
        };
    }

    private boolean notZero(BigDecimal v) {
        return v != null && v.compareTo(BigDecimal.ZERO) > 0;
    }

    private String fmtCurr(BigDecimal v) {
        if (v == null) return "₹0.00";
        return "₹" + v.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private String fmtPlain(BigDecimal v) {
        if (v == null) return "0.00";
        return v.setScale(2, RoundingMode.HALF_UP).toPlainString();
    }

    private String fmtQty(BigDecimal v) {
        if (v == null) return "0";
        return v.stripTrailingZeros().toPlainString();
    }

    private String esc(String text) {
        if (text == null) return "";
        return text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
