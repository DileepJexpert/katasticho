package com.katasticho.erp.estimate.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.estimate.dto.EstimateResponse;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
public class EstimatePdfService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy");

    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;

    public byte[] generatePdf(EstimateResponse estimate) {
        Organisation org = organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
        return pdfService.render(buildHtml(estimate, org));
    }

    /** Called by email service when org is already loaded — avoids a redundant DB lookup. */
    public byte[] generatePdf(EstimateResponse estimate, Organisation org) {
        return pdfService.render(buildHtml(estimate, org));
    }

    /** Package-visible: reused by email service to embed HTML in email body. */
    String buildHtml(EstimateResponse est, Organisation org) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");

        // ── Header: org (left) | ESTIMATE label (right) ───────────────────────
        sb.append("<table width='100%' class='hdr'><tr>");
        sb.append("<td class='org-cell'>");
        sb.append("<div class='org-name'>").append(esc(org.getName())).append("</div>");
        orgAddress(sb, org);
        sb.append("</td>");
        sb.append("<td class='est-title-cell'>");
        sb.append("<div class='est-title'>ESTIMATE</div>");
        sb.append("<div class='est-number'>").append(esc(est.estimateNumber())).append("</div>");
        sb.append("<div class='est-status ").append(statusClass(est.status())).append("'>")
                .append(esc(est.status().replace("_", " "))).append("</div>");
        sb.append("</td></tr></table>");

        sb.append("<hr class='divider'/>");

        // ── Subject (if present) ───────────────────────────────────────────────
        if (est.subject() != null && !est.subject().isBlank()) {
            sb.append("<div class='subject'>").append(esc(est.subject())).append("</div>");
            sb.append("<div style='margin-bottom:10px;'></div>");
        }

        // ── Meta: Estimate For (left) | Dates (right) ─────────────────────────
        sb.append("<table width='100%' class='meta'><tr>");
        sb.append("<td class='est-for-cell'>");
        sb.append("<div class='lbl'>ESTIMATE FOR</div>");
        sb.append("<div class='contact-name'>").append(esc(est.contactName())).append("</div>");
        if (est.referenceNumber() != null && !est.referenceNumber().isBlank()) {
            sb.append("<div class='ref-num'>Ref: ").append(esc(est.referenceNumber())).append("</div>");
        }
        sb.append("</td>");
        sb.append("<td class='dates-cell'>");
        if (est.estimateDate() != null) {
            dateLine(sb, "Estimate Date", est.estimateDate().format(DATE_FMT));
        }
        if (est.expiryDate() != null) {
            dateLine(sb, "Valid Until", est.expiryDate().format(DATE_FMT));
        }
        sb.append("</td></tr></table>");

        // ── Line items table ───────────────────────────────────────────────────
        sb.append("<table class='items'>");
        sb.append("<thead><tr>");
        sb.append("<th class='th-desc'>Description</th>");
        sb.append("<th class='th-hsn'>HSN/SAC</th>");
        sb.append("<th class='th-num'>Unit</th>");
        sb.append("<th class='th-num'>Qty</th>");
        sb.append("<th class='th-num'>Rate (&#8377;)</th>");
        sb.append("<th class='th-num'>Tax%</th>");
        sb.append("<th class='th-num'>Amount (&#8377;)</th>");
        sb.append("</tr></thead><tbody>");

        boolean odd = true;
        for (EstimateResponse.LineResponse line : est.lines()) {
            sb.append("<tr class='").append(odd ? "row-odd" : "row-even").append("'>");
            sb.append("<td class='td-left'>").append(esc(line.description())).append("</td>");
            sb.append("<td class='td-center'>").append(line.hsnCode() != null ? esc(line.hsnCode()) : "").append("</td>");
            sb.append("<td class='td-center'>").append(line.unit() != null ? esc(line.unit()) : "").append("</td>");
            sb.append("<td class='td-right'>").append(fmtQty(line.quantity())).append("</td>");
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
        sb.append("<td class='totals-spacer'></td>");
        sb.append("<td class='totals-cell'>");
        sb.append("<table class='totals-tbl'>");
        totalRow(sb, "Subtotal", fmtCurr(est.subtotal()), false, false);
        if (notZero(est.discountAmount())) {
            totalRow(sb, "Discount", "-" + fmtCurr(est.discountAmount()), false, false);
        }
        if (notZero(est.taxAmount())) {
            totalRow(sb, "Tax", fmtCurr(est.taxAmount()), false, false);
        }
        sb.append("<tr><td colspan='2'><hr class='totals-hr'/></td></tr>");
        totalRow(sb, "Total", fmtCurr(est.total()), true, false);
        sb.append("</table>");
        sb.append("</td></tr></table>");

        // ── Notes ─────────────────────────────────────────────────────────────
        if (est.notes() != null && !est.notes().isBlank()) {
            sb.append("<div class='notes'>");
            sb.append("<div class='lbl'>NOTES</div>");
            sb.append("<div class='notes-text'>").append(esc(est.notes())).append("</div>");
            sb.append("</div>");
        }

        // ── Terms & Conditions ─────────────────────────────────────────────────
        if (est.terms() != null && !est.terms().isBlank()) {
            sb.append("<div class='notes'>");
            sb.append("<div class='lbl'>TERMS &amp; CONDITIONS</div>");
            sb.append("<div class='notes-text'>").append(esc(est.terms())).append("</div>");
            sb.append("</div>");
        }

        // ── Footer ────────────────────────────────────────────────────────────
        sb.append("<div class='footer'>Powered by Katasticho</div>");

        sb.append("</body></html>");
        return sb.toString();
    }

    // ── Private helpers ────────────────────────────────────────────────────────

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

    private void totalRow(StringBuilder sb, String label, String value, boolean bold, boolean red) {
        String valClass = red ? " class='bal-amt'" : "";
        sb.append("<tr>");
        sb.append("<td class='totals-lbl'>").append(bold ? "<b>" + label + "</b>" : label).append("</td>");
        sb.append("<td class='totals-val'").append(valClass).append(">")
                .append(bold ? "<b>" + value + "</b>" : value).append("</td>");
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
                .est-title-cell { width: 40%; text-align: right; }
                .est-title { font-size: 28px; font-weight: bold; color: #2563EB; letter-spacing: 3px; }
                .est-number { font-size: 13px; font-weight: bold; color: #0F172A; margin-top: 2px; }
                .est-status { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 8px; font-weight: bold; margin-top: 5px; }
                .status-draft { background: #F1F5F9; color: #64748B; }
                .status-sent { background: #DBEAFE; color: #1D4ED8; }
                .status-accepted { background: #D1FAE5; color: #065F46; }
                .status-declined { background: #FEE2E2; color: #991B1B; }
                .status-converted { background: #EDE9FE; color: #5B21B6; }
                .divider { border: none; border-top: 1.5px solid #E2E8F0; margin: 8px 0 12px; }
                .subject { font-size: 14px; font-weight: bold; color: #0F172A; }
                .meta td { vertical-align: top; padding-bottom: 14px; }
                .est-for-cell { width: 55%; }
                .dates-cell { width: 45%; text-align: right; }
                .lbl { font-size: 7.5px; font-weight: bold; color: #94A3B8; letter-spacing: 1.5px; margin-bottom: 4px; text-transform: uppercase; }
                .contact-name { font-size: 13px; font-weight: bold; color: #0F172A; }
                .ref-num { font-size: 9px; color: #64748B; margin-top: 2px; }
                .date-row { font-size: 9px; line-height: 1.9; }
                .date-lbl { color: #64748B; }
                .items { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 9.5px; }
                .items thead tr { background: #2563EB; color: white; }
                .items thead th { padding: 7px 8px; text-align: right; font-size: 8px; font-weight: bold; letter-spacing: 0.4px; }
                .th-desc { text-align: left !important; width: 34%; }
                .th-hsn { text-align: center !important; width: 10%; }
                .th-num { width: 9%; }
                .row-odd { background: #F8FAFC; }
                .row-even { background: #FFFFFF; }
                .items tbody td { padding: 6px 8px; border-bottom: 1px solid #E2E8F0; }
                .td-left { text-align: left; }
                .td-center { text-align: center; color: #64748B; }
                .td-right { text-align: right; }
                .totals-outer td { vertical-align: top; padding-top: 4px; }
                .totals-spacer { width: 55%; }
                .totals-cell { width: 45%; text-align: right; }
                .totals-tbl { width: 100%; border-collapse: collapse; font-size: 10px; }
                .totals-lbl { padding: 3px 0; text-align: left; color: #475569; }
                .totals-val { padding: 3px 0; text-align: right; }
                .totals-hr { border: none; border-top: 1.5px solid #E2E8F0; margin: 4px 0; }
                .bal-amt { color: #DC2626; }
                .notes { margin-top: 16px; margin-bottom: 12px; }
                .notes-text { font-size: 9.5px; color: #475569; line-height: 1.6; margin-top: 4px; }
                .footer { text-align: center; font-size: 7.5px; color: #CBD5E1; margin-top: 20px; padding-top: 8px; border-top: 1px solid #E2E8F0; }
                """;
    }

    private String statusClass(String status) {
        return switch (status.toUpperCase()) {
            case "SENT" -> "status-sent";
            case "ACCEPTED" -> "status-accepted";
            case "DECLINED" -> "status-declined";
            case "CONVERTED" -> "status-converted";
            default -> "status-draft";
        };
    }

    private boolean notZero(BigDecimal v) {
        return v != null && v.compareTo(BigDecimal.ZERO) > 0;
    }

    private String fmtCurr(BigDecimal v) {
        if (v == null) return "\u20B90.00";
        return "\u20B9" + v.setScale(2, RoundingMode.HALF_UP).toPlainString();
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
