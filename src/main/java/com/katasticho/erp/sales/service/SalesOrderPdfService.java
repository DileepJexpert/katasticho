package com.katasticho.erp.sales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.common.util.AmountToWordsConverter;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.sales.dto.SalesOrderLineResponse;
import com.katasticho.erp.sales.dto.SalesOrderResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
public class SalesOrderPdfService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy");

    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;

    public byte[] generatePdf(SalesOrderResponse so) {
        Organisation org = organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
        return pdfService.render(buildHtml(so, org));
    }

    String buildHtml(SalesOrderResponse so, Organisation org) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");

        // ── Header ────────────────────────────────────────────────────────────
        sb.append("<table width='100%' class='hdr'><tr>");
        sb.append("<td class='org-cell'>");
        sb.append("<div class='org-name'>").append(esc(org.getName())).append("</div>");
        orgAddress(sb, org);
        sb.append("</td>");
        sb.append("<td class='inv-title-cell'>");
        sb.append("<div class='inv-title'>SALES ORDER</div>");
        sb.append("<div class='inv-number'>").append(esc(so.salesOrderNumber())).append("</div>");
        sb.append("<div class='inv-status ").append(statusClass(so.status())).append("'>")
                .append(esc(so.status().replace("_", " "))).append("</div>");
        sb.append("</td></tr></table>");

        sb.append("<hr class='divider'/>");

        // ── Meta: customer (left) | dates (right) ────────────────────────────
        sb.append("<table width='100%' class='meta'><tr>");
        sb.append("<td class='bill-to-cell'>");
        sb.append("<div class='lbl'>CUSTOMER</div>");
        sb.append("<div class='contact-name'>").append(esc(so.contactName())).append("</div>");
        if (so.referenceNumber() != null && !so.referenceNumber().isBlank()) {
            sb.append("<div class='ref'>Ref: ").append(esc(so.referenceNumber())).append("</div>");
        }
        sb.append("</td>");
        sb.append("<td class='dates-cell'>");
        if (so.orderDate() != null) {
            dateLine(sb, "Order Date", so.orderDate().format(DATE_FMT));
        }
        if (so.expectedShipmentDate() != null) {
            dateLine(sb, "Expected Shipment", so.expectedShipmentDate().format(DATE_FMT));
        }
        if (so.placeOfSupply() != null && !so.placeOfSupply().isBlank()) {
            dateLine(sb, "Place of Supply", so.placeOfSupply());
        }
        if (so.deliveryMethod() != null && !so.deliveryMethod().isBlank()) {
            dateLine(sb, "Delivery Method", so.deliveryMethod());
        }
        sb.append("</td></tr></table>");

        // ── Shipping address ──────────────────────────────────────────────────
        if (so.shippingAddress() != null && !so.shippingAddress().isBlank()) {
            sb.append("<div class='ship-box'>");
            sb.append("<div class='lbl'>SHIP TO</div>");
            sb.append("<div class='ship-addr'>").append(esc(so.shippingAddress())).append("</div>");
            sb.append("</div>");
        }

        // ── Line items table ──────────────────────────────────────────────────
        sb.append("<table class='items'>");
        sb.append("<thead><tr>");
        sb.append("<th class='th-desc'>Description</th>");
        sb.append("<th class='th-hsn'>HSN/SAC</th>");
        sb.append("<th class='th-num'>Qty</th>");
        sb.append("<th class='th-unit'>Unit</th>");
        sb.append("<th class='th-num'>Rate (&#8377;)</th>");
        sb.append("<th class='th-num'>Tax%</th>");
        sb.append("<th class='th-num'>Amount (&#8377;)</th>");
        sb.append("</tr></thead><tbody>");

        boolean odd = true;
        for (SalesOrderLineResponse line : so.lines()) {
            sb.append("<tr class='").append(odd ? "row-odd" : "row-even").append("'>");
            sb.append("<td class='td-left'>").append(esc(line.description())).append("</td>");
            sb.append("<td class='td-center'>").append(line.hsnCode() != null ? esc(line.hsnCode()) : "").append("</td>");
            sb.append("<td class='td-right'>").append(fmtQty(line.quantity())).append("</td>");
            sb.append("<td class='td-center'>").append(line.unit() != null ? esc(line.unit()) : "").append("</td>");
            sb.append("<td class='td-right'>").append(fmtPlain(line.rate())).append("</td>");
            sb.append("<td class='td-right'>")
                    .append(line.taxRate() != null ? line.taxRate().stripTrailingZeros().toPlainString() + "%" : "")
                    .append("</td>");
            sb.append("<td class='td-right'>").append(fmtPlain(line.amount())).append("</td>");
            sb.append("</tr>");
            odd = !odd;
        }
        sb.append("</tbody></table>");

        // ── Totals ────────────────────────────────────────────────────────────
        sb.append("<table width='100%' class='totals-outer'><tr>");
        sb.append("<td class='tax-cell'></td>");
        sb.append("<td class='totals-cell'>");
        sb.append("<table class='totals-tbl'>");
        totalRow(sb, "Subtotal", fmtCurr(so.subtotal()), false);
        if (notZero(so.discountAmount())) {
            totalRow(sb, "Discount", "- " + fmtCurr(so.discountAmount()), false);
        }
        if (notZero(so.taxAmount())) {
            totalRow(sb, "Tax", fmtCurr(so.taxAmount()), false);
        }
        if (notZero(so.shippingCharge())) {
            totalRow(sb, "Shipping", fmtCurr(so.shippingCharge()), false);
        }
        if (so.adjustment() != null && so.adjustment().compareTo(BigDecimal.ZERO) != 0) {
            String adjLabel = so.adjustmentDescription() != null && !so.adjustmentDescription().isBlank()
                    ? so.adjustmentDescription() : "Adjustment";
            totalRow(sb, adjLabel, fmtCurr(so.adjustment()), false);
        }
        sb.append("<tr><td colspan='2'><hr class='totals-hr'/></td></tr>");
        totalRow(sb, "Total", fmtCurr(so.totalAmount()), true);
        sb.append("</table>");
        sb.append("</td></tr></table>");

        // ── Amount in words ───────────────────────────────────────────────────
        if (notZero(so.totalAmount())) {
            sb.append("<div class='words'>");
            sb.append("<span class='lbl'>AMOUNT IN WORDS: </span>");
            sb.append("<span class='words-text'>").append(AmountToWordsConverter.convert(so.totalAmount())).append("</span>");
            sb.append("</div>");
        }

        // ── Notes & Terms ─────────────────────────────────────────────────────
        if (so.notes() != null && !so.notes().isBlank()) {
            sb.append("<div class='notes'>");
            sb.append("<div class='lbl'>NOTES</div>");
            sb.append("<div class='notes-text'>").append(esc(so.notes())).append("</div>");
            sb.append("</div>");
        }
        if (so.terms() != null && !so.terms().isBlank()) {
            sb.append("<div class='notes'>");
            sb.append("<div class='lbl'>TERMS &amp; CONDITIONS</div>");
            sb.append("<div class='notes-text'>").append(esc(so.terms())).append("</div>");
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
                .inv-title { font-size: 24px; font-weight: bold; color: #059669; letter-spacing: 2px; }
                .inv-number { font-size: 13px; font-weight: bold; color: #0F172A; margin-top: 2px; }
                .inv-status { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 8px; font-weight: bold; margin-top: 5px; }
                .status-draft { background: #F1F5F9; color: #64748B; }
                .status-confirmed { background: #D1FAE5; color: #065F46; }
                .status-cancelled { background: #F1F5F9; color: #94A3B8; }
                .divider { border: none; border-top: 1.5px solid #E2E8F0; margin: 8px 0 12px; }
                .meta td { vertical-align: top; padding-bottom: 14px; }
                .bill-to-cell { width: 55%; }
                .dates-cell { width: 45%; text-align: right; }
                .lbl { font-size: 7.5px; font-weight: bold; color: #94A3B8; letter-spacing: 1.5px; margin-bottom: 4px; text-transform: uppercase; }
                .contact-name { font-size: 13px; font-weight: bold; color: #0F172A; }
                .ref { font-size: 9px; color: #64748B; margin-top: 3px; }
                .ship-box { margin-bottom: 12px; padding: 8px 10px; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 4px; }
                .ship-addr { font-size: 9.5px; color: #334155; line-height: 1.5; margin-top: 4px; }
                .date-row { font-size: 9px; line-height: 1.9; }
                .date-lbl { color: #64748B; }
                .items { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 9.5px; }
                .items thead tr { background: #059669; color: white; }
                .items thead th { padding: 7px 8px; text-align: right; font-size: 8px; font-weight: bold; letter-spacing: 0.4px; }
                .th-desc { text-align: left !important; width: 30%; }
                .th-hsn { text-align: center !important; width: 10%; }
                .th-unit { text-align: center !important; width: 8%; }
                .th-num { width: 10%; }
                .row-odd { background: #F0FDF4; }
                .row-even { background: #FFFFFF; }
                .items tbody td { padding: 6px 8px; border-bottom: 1px solid #D1FAE5; }
                .td-left { text-align: left; }
                .td-center { text-align: center; color: #64748B; }
                .td-right { text-align: right; }
                .totals-outer td { vertical-align: top; padding-top: 4px; }
                .tax-cell { width: 52%; padding-right: 12px; }
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
            case "CONFIRMED" -> "status-confirmed";
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
