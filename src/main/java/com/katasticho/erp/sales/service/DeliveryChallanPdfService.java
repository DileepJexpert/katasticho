package com.katasticho.erp.sales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.sales.dto.DeliveryChallanLineResponse;
import com.katasticho.erp.sales.dto.DeliveryChallanResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
public class DeliveryChallanPdfService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM yyyy");

    private final DocumentPdfService pdfService;
    private final OrganisationRepository organisationRepository;

    public byte[] generatePdf(DeliveryChallanResponse dc) {
        Organisation org = organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
        return pdfService.render(buildHtml(dc, org));
    }

    String buildHtml(DeliveryChallanResponse dc, Organisation org) {
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
        sb.append("<div class='inv-title'>DELIVERY CHALLAN</div>");
        sb.append("<div class='inv-number'>").append(esc(dc.challanNumber())).append("</div>");
        sb.append("<div class='inv-status ").append(statusClass(dc.status())).append("'>")
                .append(esc(dc.status().replace("_", " "))).append("</div>");
        sb.append("</td></tr></table>");

        sb.append("<hr class='divider'/>");

        // ── Meta: customer (left) | dates & shipment (right) ─────────────────
        sb.append("<table width='100%' class='meta'><tr>");
        sb.append("<td class='bill-to-cell'>");
        sb.append("<div class='lbl'>DELIVER TO</div>");
        sb.append("<div class='contact-name'>").append(esc(dc.contactName())).append("</div>");
        if (dc.salesOrderNumber() != null && !dc.salesOrderNumber().isBlank()) {
            sb.append("<div class='ref'>Sales Order: ").append(esc(dc.salesOrderNumber())).append("</div>");
        }
        if (dc.shippingAddress() != null && !dc.shippingAddress().isBlank()) {
            sb.append("<div class='ship-addr'>").append(esc(dc.shippingAddress())).append("</div>");
        }
        sb.append("</td>");
        sb.append("<td class='dates-cell'>");
        if (dc.challanDate() != null) {
            dateLine(sb, "Challan Date", dc.challanDate().format(DATE_FMT));
        }
        if (dc.dispatchDate() != null) {
            dateLine(sb, "Dispatch Date", dc.dispatchDate().format(DATE_FMT));
        }
        if (dc.deliveryMethod() != null && !dc.deliveryMethod().isBlank()) {
            dateLine(sb, "Delivery Method", dc.deliveryMethod());
        }
        if (dc.vehicleNumber() != null && !dc.vehicleNumber().isBlank()) {
            dateLine(sb, "Vehicle No.", dc.vehicleNumber());
        }
        if (dc.trackingNumber() != null && !dc.trackingNumber().isBlank()) {
            dateLine(sb, "Tracking No.", dc.trackingNumber());
        }
        if (dc.warehouseName() != null && !dc.warehouseName().isBlank()) {
            dateLine(sb, "Warehouse", dc.warehouseName());
        }
        sb.append("</td></tr></table>");

        // ── Line items (quantities only — no pricing) ─────────────────────────
        sb.append("<table class='items'>");
        sb.append("<thead><tr>");
        sb.append("<th class='th-sno'>S.No</th>");
        sb.append("<th class='th-desc'>Item</th>");
        sb.append("<th class='th-batch'>Batch</th>");
        sb.append("<th class='th-qty'>Qty</th>");
        sb.append("<th class='th-unit'>Unit</th>");
        sb.append("</tr></thead><tbody>");

        boolean odd = true;
        int sno = 1;
        for (DeliveryChallanLineResponse line : dc.lines()) {
            sb.append("<tr class='").append(odd ? "row-odd" : "row-even").append("'>");
            sb.append("<td class='td-center'>").append(sno++).append("</td>");
            sb.append("<td class='td-left'>");
            if (line.itemName() != null && !line.itemName().isBlank()) {
                sb.append(esc(line.itemName()));
            }
            if (line.description() != null && !line.description().isBlank()) {
                if (line.itemName() != null && !line.itemName().isBlank()) {
                    sb.append("<br/><span class='line-desc'>").append(esc(line.description())).append("</span>");
                } else {
                    sb.append(esc(line.description()));
                }
            }
            sb.append("</td>");
            sb.append("<td class='td-center'>").append(line.batchNumber() != null ? esc(line.batchNumber()) : "").append("</td>");
            sb.append("<td class='td-right'>").append(fmtQty(line.quantity())).append("</td>");
            sb.append("<td class='td-center'>").append(line.unit() != null ? esc(line.unit()) : "").append("</td>");
            sb.append("</tr>");
            odd = !odd;
        }
        sb.append("</tbody></table>");

        // ── Notes ─────────────────────────────────────────────────────────────
        if (dc.notes() != null && !dc.notes().isBlank()) {
            sb.append("<div class='notes'>");
            sb.append("<div class='lbl'>NOTES</div>");
            sb.append("<div class='notes-text'>").append(esc(dc.notes())).append("</div>");
            sb.append("</div>");
        }

        // ── Signature block ──────────────────────────────────────────────────
        sb.append("<table width='100%' class='sig-tbl'><tr>");
        sb.append("<td class='sig-cell'>");
        sb.append("<div class='sig-line'></div>");
        sb.append("<div class='sig-lbl'>Prepared By</div>");
        sb.append("</td>");
        sb.append("<td class='sig-cell'>");
        sb.append("<div class='sig-line'></div>");
        sb.append("<div class='sig-lbl'>Received By</div>");
        sb.append("</td>");
        sb.append("</tr></table>");

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
    }

    private void dateLine(StringBuilder sb, String label, String value) {
        sb.append("<div class='date-row'><span class='date-lbl'>").append(label)
                .append(":</span> ").append(esc(value)).append("</div>");
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
                .inv-title { font-size: 20px; font-weight: bold; color: #7C3AED; letter-spacing: 1.5px; }
                .inv-number { font-size: 13px; font-weight: bold; color: #0F172A; margin-top: 2px; }
                .inv-status { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 8px; font-weight: bold; margin-top: 5px; }
                .status-draft { background: #F1F5F9; color: #64748B; }
                .status-confirmed { background: #DBEAFE; color: #1D4ED8; }
                .status-dispatched { background: #FEF3C7; color: #92400E; }
                .status-delivered { background: #D1FAE5; color: #065F46; }
                .status-cancelled { background: #F1F5F9; color: #94A3B8; }
                .divider { border: none; border-top: 1.5px solid #E2E8F0; margin: 8px 0 12px; }
                .meta td { vertical-align: top; padding-bottom: 14px; }
                .bill-to-cell { width: 55%; }
                .dates-cell { width: 45%; text-align: right; }
                .lbl { font-size: 7.5px; font-weight: bold; color: #94A3B8; letter-spacing: 1.5px; margin-bottom: 4px; text-transform: uppercase; }
                .contact-name { font-size: 13px; font-weight: bold; color: #0F172A; }
                .ref { font-size: 9px; color: #64748B; margin-top: 3px; }
                .ship-addr { font-size: 9px; color: #475569; line-height: 1.5; margin-top: 4px; }
                .date-row { font-size: 9px; line-height: 1.9; }
                .date-lbl { color: #64748B; }
                .items { width: 100%; border-collapse: collapse; margin-bottom: 14px; font-size: 9.5px; }
                .items thead tr { background: #7C3AED; color: white; }
                .items thead th { padding: 7px 8px; text-align: right; font-size: 8px; font-weight: bold; letter-spacing: 0.4px; }
                .th-sno { text-align: center !important; width: 8%; }
                .th-desc { text-align: left !important; width: 42%; }
                .th-batch { text-align: center !important; width: 18%; }
                .th-qty { width: 16%; }
                .th-unit { text-align: center !important; width: 16%; }
                .row-odd { background: #FAF5FF; }
                .row-even { background: #FFFFFF; }
                .items tbody td { padding: 6px 8px; border-bottom: 1px solid #EDE9FE; }
                .td-left { text-align: left; }
                .td-center { text-align: center; color: #64748B; }
                .td-right { text-align: right; }
                .line-desc { font-size: 8px; color: #94A3B8; }
                .sig-tbl { margin-top: 40px; }
                .sig-cell { width: 40%; text-align: center; padding: 0 20px; }
                .sig-line { border-bottom: 1px solid #94A3B8; margin-bottom: 6px; height: 30px; }
                .sig-lbl { font-size: 8px; color: #64748B; }
                .notes { margin-top: 16px; margin-bottom: 12px; }
                .notes-text { font-size: 9.5px; color: #475569; line-height: 1.6; margin-top: 4px; }
                .footer { text-align: center; font-size: 7.5px; color: #CBD5E1; margin-top: 20px; padding-top: 8px; border-top: 1px solid #E2E8F0; }
                """;
    }

    private String statusClass(String status) {
        return switch (status.toUpperCase()) {
            case "CONFIRMED" -> "status-confirmed";
            case "DISPATCHED", "SHIPPED" -> "status-dispatched";
            case "DELIVERED" -> "status-delivered";
            case "CANCELLED" -> "status-cancelled";
            default -> "status-draft";
        };
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
