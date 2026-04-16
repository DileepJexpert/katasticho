package com.katasticho.erp.pos.service;

import com.katasticho.erp.ar.entity.TaxLineItem;
import com.katasticho.erp.ar.repository.TaxLineItemRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.pos.dto.SalesReceiptResponse;
import com.openhtmltopdf.pdfboxout.PdfRendererBuilder;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReceiptPdfService {

    private static final DateTimeFormatter DATE_FMT =
            DateTimeFormatter.ofPattern("dd MMM yyyy HH:mm");
    private static final int RECEIPT_WIDTH_MM = 58;

    private final OrganisationRepository organisationRepository;
    private final TaxLineItemRepository taxLineItemRepository;
    private final SalesReceiptService salesReceiptService;

    public byte[] generateReceiptPdf(UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        SalesReceiptResponse receipt = salesReceiptService.getById(receiptId);

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        List<TaxLineItem> taxLines = taxLineItemRepository
                .findBySourceTypeAndSourceId("SALES_RECEIPT", receiptId);

        // Aggregate tax components by code
        Map<String, BigDecimal> taxByComponent = taxLines.stream()
                .collect(Collectors.groupingBy(
                        TaxLineItem::getComponentCode,
                        Collectors.reducing(BigDecimal.ZERO, TaxLineItem::getTaxAmount, BigDecimal::add)));

        String html = buildReceiptHtml(receipt, org, taxByComponent);

        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            PdfRendererBuilder builder = new PdfRendererBuilder();
            builder.useFastMode();
            builder.withHtmlContent(html, null);
            builder.toStream(baos);
            builder.run();
            return baos.toByteArray();
        } catch (Exception e) {
            log.error("Failed to generate receipt PDF for {}", receiptId, e);
            throw new BusinessException("PDF generation failed", "PDF_ERROR");
        }
    }

    private String buildReceiptHtml(SalesReceiptResponse receipt,
                                     Organisation org,
                                     Map<String, BigDecimal> taxByComponent) {

        String receiptDate = receipt.createdAt() != null
                ? receipt.createdAt().atZone(ZoneId.of(org.getTimezone())).format(DATE_FMT)
                : receipt.receiptDate().toString();

        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html><html><head><style>");
        sb.append(receiptCss());
        sb.append("</style></head><body><div class='receipt'>");

        // Header — store name, address, GSTIN
        sb.append("<div class='header'>");
        sb.append("<div class='store-name'>").append(esc(org.getName())).append("</div>");
        if (org.getAddressLine1() != null) {
            sb.append("<div class='addr'>").append(esc(org.getAddressLine1()));
            if (org.getCity() != null) sb.append(", ").append(esc(org.getCity()));
            sb.append("</div>");
        }
        if (org.getGstin() != null) {
            sb.append("<div class='gstin'>GSTIN: ").append(esc(org.getGstin())).append("</div>");
        }
        sb.append("</div>");

        // Receipt info
        sb.append("<div class='info'>");
        sb.append("<div>Receipt: ").append(esc(receipt.receiptNumber())).append("</div>");
        sb.append("<div>Date: ").append(receiptDate).append("</div>");
        if (receipt.contactName() != null) {
            sb.append("<div>Customer: ").append(esc(receipt.contactName())).append("</div>");
        }
        sb.append("</div>");

        sb.append("<div class='sep'></div>");

        // Line items
        sb.append("<table class='items'>");
        for (SalesReceiptResponse.LineResponse line : receipt.lines()) {
            String name = line.itemName() != null ? line.itemName()
                    : (line.description() != null ? line.description() : "Item");
            sb.append("<tr><td colspan='2' class='item-name'>").append(esc(name)).append("</td></tr>");
            sb.append("<tr>");
            sb.append("<td class='item-detail'>  ")
                    .append(fmtQty(line.quantity())).append(" x ")
                    .append(fmtAmt(line.rate())).append("</td>");
            sb.append("<td class='item-amt'>").append(fmtAmt(line.amount())).append("</td>");
            sb.append("</tr>");
        }
        sb.append("</table>");

        sb.append("<div class='sep'></div>");

        // Totals
        sb.append("<table class='totals'>");
        sb.append("<tr><td>Subtotal</td><td class='r'>").append(fmtAmt(receipt.subtotal())).append("</td></tr>");

        for (var entry : taxByComponent.entrySet()) {
            sb.append("<tr><td>").append(esc(entry.getKey())).append("</td>");
            sb.append("<td class='r'>").append(fmtAmt(entry.getValue())).append("</td></tr>");
        }

        sb.append("<tr class='total-row'><td><b>Total</b></td><td class='r'><b>")
                .append(fmtAmt(receipt.total())).append("</b></td></tr>");
        sb.append("</table>");

        sb.append("<div class='sep'></div>");

        // Payment info
        sb.append("<table class='totals'>");
        sb.append("<tr><td>Paid ").append(receipt.paymentMode()).append("</td>");
        sb.append("<td class='r'>").append(fmtAmt(receipt.amountReceived())).append("</td></tr>");
        if (receipt.changeReturned() != null && receipt.changeReturned().compareTo(BigDecimal.ZERO) > 0) {
            sb.append("<tr><td>Change</td><td class='r'>").append(fmtAmt(receipt.changeReturned())).append("</td></tr>");
        }
        sb.append("</table>");

        // Footer
        sb.append("<div class='footer'>");
        sb.append("<div>Thank you, visit again!</div>");
        sb.append("<div class='branding'>Powered by Katasticho</div>");
        sb.append("</div>");

        sb.append("</div></body></html>");
        return sb.toString();
    }

    private String receiptCss() {
        return """
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: 'Courier New', monospace; font-size: 10px; width: 58mm; }
            .receipt { padding: 4mm 3mm; }
            .header { text-align: center; margin-bottom: 3mm; }
            .store-name { font-size: 13px; font-weight: bold; }
            .addr, .gstin { font-size: 9px; color: #555; }
            .info { font-size: 9px; margin-bottom: 2mm; }
            .sep { border-top: 1px dashed #000; margin: 2mm 0; }
            .items { width: 100%; font-size: 10px; }
            .item-name { font-weight: bold; }
            .item-detail { font-size: 9px; color: #333; }
            .item-amt { text-align: right; }
            .totals { width: 100%; font-size: 10px; }
            .totals td { padding: 1px 0; }
            .r { text-align: right; }
            .total-row { font-size: 12px; border-top: 1px solid #000; }
            .footer { text-align: center; margin-top: 4mm; font-size: 9px; }
            .branding { font-size: 8px; color: #999; margin-top: 2mm; }
            """;
    }

    private String fmtAmt(BigDecimal amount) {
        if (amount == null) return "0.00";
        return "\u20B9" + amount.setScale(2, java.math.RoundingMode.HALF_UP).toPlainString();
    }

    private String fmtQty(BigDecimal qty) {
        if (qty == null) return "0";
        return qty.stripTrailingZeros().toPlainString();
    }

    private String esc(String text) {
        if (text == null) return "";
        return text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
