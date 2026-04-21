package com.katasticho.erp.ap.service;

import com.katasticho.erp.ap.dto.PurchaseBillResponse;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
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
public class BillPdfService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy");

    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;

    public byte[] generatePdf(PurchaseBillResponse bill) {
        Organisation org = organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
        return pdfService.render(buildHtml(bill, org));
    }

    String buildHtml(PurchaseBillResponse bill, Organisation org) {
        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><meta charset='UTF-8'/><style>");
        sb.append(css());
        sb.append("</style></head><body>");

        // ── Header: org (left) | PURCHASE BILL (right) ────────────────────────
        sb.append("<table width='100%' class='hdr'><tr>");
        sb.append("<td class='org-cell'>");
        sb.append("<div class='org-name'>").append(esc(org.getName())).append("</div>");
        orgAddress(sb, org);
        sb.append("</td>");
        sb.append("<td class='inv-title-cell'>");
        sb.append("<div class='inv-title'>PURCHASE BILL</div>");
        sb.append("<div class='inv-number'>").append(esc(bill.billNumber())).append("</div>");
        sb.append("<div class='inv-status ").append(statusClass(bill.status())).append("'>")
                .append(esc(bill.status().replace("_", " "))).append("</div>");
        sb.append("</td></tr></table>");

        sb.append("<hr class='divider'/>");

        // ── Meta: vendor (left) | dates (right) ──────────────────────────────
        sb.append("<table width='100%' class='meta'><tr>");
        sb.append("<td class='bill-to-cell'>");
        sb.append("<div class='lbl'>VENDOR</div>");
        sb.append("<div class='contact-name'>").append(esc(bill.vendorName())).append("</div>");
        if (bill.vendorBillNumber() != null && !bill.vendorBillNumber().isBlank()) {
            sb.append("<div class='vendor-ref'>Ref: ").append(esc(bill.vendorBillNumber())).append("</div>");
        }
        sb.append("</td>");
        sb.append("<td class='dates-cell'>");
        if (bill.billDate() != null) {
            dateLine(sb, "Bill Date", bill.billDate().format(DATE_FMT));
        }
        if (bill.dueDate() != null) {
            dateLine(sb, "Due Date", bill.dueDate().format(DATE_FMT));
        }
        if (bill.placeOfSupply() != null && !bill.placeOfSupply().isBlank()) {
            dateLine(sb, "Place of Supply", bill.placeOfSupply());
        }
        if (bill.reverseCharge()) {
            dateLine(sb, "Reverse Charge", "Yes");
        }
        sb.append("</td></tr></table>");

        // ── Line items table ───────────────────────────────────────────────────
        sb.append("<table class='items'>");
        sb.append("<thead><tr>");
        sb.append("<th class='th-desc'>Description</th>");
        sb.append("<th class='th-hsn'>HSN/SAC</th>");
        sb.append("<th class='th-num'>Qty</th>");
        sb.append("<th class='th-num'>Rate (&#8377;)</th>");
        sb.append("<th class='th-num'>GST%</th>");
        sb.append("<th class='th-num'>Amount (&#8377;)</th>");
        sb.append("</tr></thead><tbody>");

        // Collect tax summary by rate while iterating lines
        Map<String, BigDecimal[]> taxByRate = new LinkedHashMap<>();

        boolean odd = true;
        for (PurchaseBillResponse.LineResponse line : bill.lines()) {
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

            // Accumulate tax summary
            if (line.gstRate() != null && notZero(line.taxAmount())) {
                String rateKey = line.gstRate().stripTrailingZeros().toPlainString() + "%";
                taxByRate.computeIfAbsent(rateKey, k -> new BigDecimal[]{BigDecimal.ZERO, BigDecimal.ZERO});
                BigDecimal taxable = line.taxableAmount() != null ? line.taxableAmount() : line.lineTotal();
                taxByRate.get(rateKey)[0] = taxByRate.get(rateKey)[0].add(taxable);
                taxByRate.get(rateKey)[1] = taxByRate.get(rateKey)[1].add(line.taxAmount());
            }
        }
        sb.append("</tbody></table>");

        // ── Totals + Tax breakdown ─────────────────────────────────────────────
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
        totalRow(sb, "Subtotal", fmtCurr(bill.subtotal()), false, false);
        if (notZero(bill.taxAmount())) {
            totalRow(sb, "Tax", fmtCurr(bill.taxAmount()), false, false);
        }
        if (notZero(bill.tdsAmount())) {
            totalRow(sb, "TDS Deducted", "- " + fmtCurr(bill.tdsAmount()), false, false);
        }
        sb.append("<tr><td colspan='2'><hr class='totals-hr'/></td></tr>");
        totalRow(sb, "Total", fmtCurr(bill.totalAmount()), true, false);
        if (notZero(bill.amountPaid())) {
            totalRow(sb, "Amount Paid", fmtCurr(bill.amountPaid()), false, false);
        }
        if (notZero(bill.balanceDue())) {
            totalRow(sb, "Balance Due", fmtCurr(bill.balanceDue()), true, true);
        }
        sb.append("</table>");
        sb.append("</td></tr></table>");

        // ── Notes ─────────────────────────────────────────────────────────────
        if (bill.notes() != null && !bill.notes().isBlank()) {
            sb.append("<div class='notes'>");
            sb.append("<div class='lbl'>NOTES</div>");
            sb.append("<div class='notes-text'>").append(esc(bill.notes())).append("</div>");
            sb.append("</div>");
        }

        sb.append("<div class='footer'>Powered by Katasticho</div>");
        sb.append("</body></html>");
        return sb.toString();
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

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
    }

    private void dateLine(StringBuilder sb, String label, String value) {
        sb.append("<div class='date-row'><span class='date-lbl'>").append(label)
                .append(":</span> ").append(esc(value)).append("</div>");
    }

    private void totalRow(StringBuilder sb, String label, String value, boolean bold, boolean red) {
        String tdStyle = red ? " class='bal-amt'" : "";
        sb.append("<tr>");
        sb.append("<td class='totals-lbl'>").append(bold ? "<b>" + label + "</b>" : label).append("</td>");
        sb.append("<td class='totals-val'").append(tdStyle).append(">")
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
                .inv-title-cell { width: 40%; text-align: right; }
                .inv-title { font-size: 22px; font-weight: bold; color: #64748B; letter-spacing: 2px; }
                .inv-number { font-size: 13px; font-weight: bold; color: #0F172A; margin-top: 2px; }
                .inv-status { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 8px; font-weight: bold; margin-top: 5px; }
                .status-draft { background: #F1F5F9; color: #64748B; }
                .status-posted { background: #DBEAFE; color: #1D4ED8; }
                .status-paid { background: #D1FAE5; color: #065F46; }
                .status-overdue { background: #FEE2E2; color: #991B1B; }
                .status-partially-paid { background: #FEF3C7; color: #92400E; }
                .status-void { background: #F1F5F9; color: #94A3B8; }
                .divider { border: none; border-top: 1.5px solid #E2E8F0; margin: 8px 0 12px; }
                .meta td { vertical-align: top; padding-bottom: 14px; }
                .bill-to-cell { width: 55%; }
                .dates-cell { width: 45%; text-align: right; }
                .lbl { font-size: 7.5px; font-weight: bold; color: #94A3B8; letter-spacing: 1.5px; margin-bottom: 4px; text-transform: uppercase; }
                .contact-name { font-size: 13px; font-weight: bold; color: #0F172A; }
                .vendor-ref { font-size: 9px; color: #64748B; margin-top: 3px; }
                .date-row { font-size: 9px; line-height: 1.9; }
                .date-lbl { color: #64748B; }
                .items { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 9.5px; }
                .items thead tr { background: #475569; color: white; }
                .items thead th { padding: 7px 8px; text-align: right; font-size: 8px; font-weight: bold; letter-spacing: 0.4px; }
                .th-desc { text-align: left !important; width: 38%; }
                .th-hsn { text-align: center !important; width: 11%; }
                .th-num { width: 10%; }
                .row-odd { background: #F8FAFC; }
                .row-even { background: #FFFFFF; }
                .items tbody td { padding: 6px 8px; border-bottom: 1px solid #E2E8F0; }
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
                .bal-amt { color: #DC2626; }
                .notes { margin-top: 16px; margin-bottom: 12px; }
                .notes-text { font-size: 9.5px; color: #475569; line-height: 1.6; margin-top: 4px; }
                .footer { text-align: center; font-size: 7.5px; color: #CBD5E1; margin-top: 20px; padding-top: 8px; border-top: 1px solid #E2E8F0; }
                """;
    }

    private String statusClass(String status) {
        return switch (status.toUpperCase()) {
            case "POSTED" -> "status-posted";
            case "PAID" -> "status-paid";
            case "OVERDUE" -> "status-overdue";
            case "PARTIALLY_PAID" -> "status-partially-paid";
            case "VOID" -> "status-void";
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
