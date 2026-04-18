package com.katasticho.erp.common.service;

import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.service.InvoicePdfService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.estimate.dto.EstimateResponse;
import com.katasticho.erp.estimate.service.EstimatePdfService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.math.RoundingMode;

@Service
@RequiredArgsConstructor
@Slf4j
public class DocumentEmailService {

    private final JavaMailSender mailSender;
    private final InvoicePdfService invoicePdfService;
    private final EstimatePdfService estimatePdfService;
    private final OrganisationRepository organisationRepository;

    @Value("${app.mail.from:noreply@katasticho.com}")
    private String fromAddress;

    @Value("${app.mail.from-name:Katasticho}")
    private String fromName;

    /**
     * Sends invoice email with PDF attachment.
     * @return true if sent, false on SMTP failure (caller logs the comment accordingly)
     */
    public boolean sendInvoice(InvoiceResponse inv, String toEmail) {
        try {
            Organisation org = loadOrg();
            byte[] pdf = invoicePdfService.generatePdf(inv, org);
            String subject = org.getName() + " \u2013 Invoice " + inv.invoiceNumber();
            String filename = "invoice-" + sanitize(inv.invoiceNumber()) + ".pdf";
            send(toEmail, subject, invoiceBody(inv, org), filename, pdf);
            log.info("Invoice {} emailed to {}", inv.invoiceNumber(), toEmail);
            return true;
        } catch (Exception e) {
            log.error("Failed to email invoice {} to {}", inv.invoiceNumber(), toEmail, e);
            return false;
        }
    }

    /**
     * Sends estimate email with PDF attachment.
     * @return true if sent, false on SMTP failure
     */
    public boolean sendEstimate(EstimateResponse est, String toEmail) {
        try {
            Organisation org = loadOrg();
            byte[] pdf = estimatePdfService.generatePdf(est, org);
            String subject = org.getName() + " \u2013 Estimate " + est.estimateNumber();
            String filename = "estimate-" + sanitize(est.estimateNumber()) + ".pdf";
            send(toEmail, subject, estimateBody(est, org), filename, pdf);
            log.info("Estimate {} emailed to {}", est.estimateNumber(), toEmail);
            return true;
        } catch (Exception e) {
            log.error("Failed to email estimate {} to {}", est.estimateNumber(), toEmail, e);
            return false;
        }
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private void send(String to, String subject, String htmlBody,
                      String attachFilename, byte[] attachment) throws Exception {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
        helper.setFrom(fromAddress, fromName);
        helper.setTo(to);
        helper.setSubject(subject);
        helper.setText(htmlBody, true);
        helper.addAttachment(attachFilename,
                () -> new ByteArrayInputStream(attachment), "application/pdf");
        mailSender.send(message);
    }

    private Organisation loadOrg() {
        return organisationRepository.findById(TenantContext.getCurrentOrgId())
                .orElseThrow(() -> BusinessException.notFound("Organisation", TenantContext.getCurrentOrgId()));
    }

    private String invoiceBody(InvoiceResponse inv, Organisation org) {
        String total = "\u20B9" + (inv.totalAmount() != null
                ? inv.totalAmount().setScale(2, RoundingMode.HALF_UP).toPlainString()
                : "0.00");
        String due = inv.dueDate() != null ? inv.dueDate().toString() : "\u2013";
        return template(org, "Invoice " + inv.invoiceNumber(),
                "<p>Please find invoice <strong>" + esc(inv.invoiceNumber()) + "</strong> attached.</p>"
                + "<table class='d'>"
                + row("Invoice #", esc(inv.invoiceNumber()))
                + row("Amount", "<strong>" + total + "</strong>")
                + row("Due Date", due)
                + "</table>"
                + "<p>Please make payment by the due date. Contact us if you have any questions.</p>");
    }

    private String estimateBody(EstimateResponse est, Organisation org) {
        String total = "\u20B9" + (est.total() != null
                ? est.total().setScale(2, RoundingMode.HALF_UP).toPlainString()
                : "0.00");
        String expires = est.expiryDate() != null ? est.expiryDate().toString() : "\u2013";
        String sub = (est.subject() != null && !est.subject().isBlank())
                ? " \u2013 " + esc(est.subject()) : "";
        return template(org, "Estimate " + est.estimateNumber() + sub,
                "<p>Please find estimate <strong>" + esc(est.estimateNumber()) + "</strong> attached.</p>"
                + "<table class='d'>"
                + row("Estimate #", esc(est.estimateNumber()))
                + row("Total", "<strong>" + total + "</strong>")
                + row("Valid Until", expires)
                + "</table>"
                + "<p>This estimate is valid until the date shown. Please contact us to proceed.</p>");
    }

    private String template(Organisation org, String docTitle, String body) {
        String orgName = esc(org.getName());
        StringBuilder footer = new StringBuilder(orgName);
        if (org.getEmail() != null && !org.getEmail().isBlank()) footer.append(" | ").append(esc(org.getEmail()));
        if (org.getPhone() != null && !org.getPhone().isBlank()) footer.append(" | ").append(esc(org.getPhone()));
        return "<!DOCTYPE html><html><head><meta charset='UTF-8'/>"
                + "<style>"
                + "body{font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#0F172A;background:#F8FAFC;margin:0}"
                + ".w{max-width:600px;margin:32px auto;background:#fff;border-radius:8px;overflow:hidden;"
                +   "box-shadow:0 1px 4px rgba(0,0,0,.08)}"
                + ".h{background:#2563EB;padding:24px 32px}"
                + ".h h1{color:#fff;font-size:20px;margin:0;font-weight:bold}"
                + ".h p{color:#BFDBFE;font-size:13px;margin:4px 0 0}"
                + ".b{padding:28px 32px}"
                + "p{margin:0 0 16px;line-height:1.6}"
                + ".d{width:100%;border-collapse:collapse;margin:16px 0}"
                + ".d td{padding:8px 12px;border-bottom:1px solid #E2E8F0;font-size:13px}"
                + ".d tr:last-child td{border-bottom:none}"
                + ".d td:first-child{color:#64748B;width:130px}"
                + ".f{background:#F1F5F9;padding:16px 32px;text-align:center;font-size:11px;color:#94A3B8}"
                + "</style></head><body>"
                + "<div class='w'>"
                + "<div class='h'><h1>" + orgName + "</h1><p>" + docTitle + "</p></div>"
                + "<div class='b'>" + body + "</div>"
                + "<div class='f'>" + footer + "<br/>Powered by Katasticho</div>"
                + "</div></body></html>";
    }

    private String row(String label, String value) {
        return "<tr><td>" + label + "</td><td>" + value + "</td></tr>";
    }

    private String sanitize(String s) {
        return s != null ? s.replaceAll("[/\\\\:*?\"<>|]", "-") : "doc";
    }

    private String esc(String text) {
        if (text == null) return "";
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
