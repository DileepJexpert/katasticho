package com.katasticho.erp.common.service;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.estimate.entity.Estimate;
import com.katasticho.erp.estimate.repository.EstimateRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DocumentShareService {

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd MMM");
    private static final String BRANDING = "\n\n\u2014 via Katasticho";

    @Value("${app.base-url:https://app.katasticho.com}")
    private String appBaseUrl;

    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final EstimateRepository estimateRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;

    public Map<String, String> shareInvoice(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        String shareUrl = buildShareUrl("invoice", orgId, invoiceId);
        String phone = resolveContactPhone(invoice.getContactId());
        String orgName = resolveOrgName(orgId);

        String message = String.format(
                "Invoice %s for %s",
                invoice.getInvoiceNumber(),
                formatAmount(invoice.getTotalAmount()));
        if (invoice.getDueDate() != null) {
            message += " due " + invoice.getDueDate().format(DATE_FMT);
        }
        message += "\n\nView: " + shareUrl;
        message += "\n\nFrom " + orgName;
        message += BRANDING;

        return buildResult(shareUrl, phone, message, invoice.getInvoiceNumber());
    }

    public Map<String, String> shareInvoiceReminder(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        String shareUrl = buildShareUrl("invoice", orgId, invoiceId);
        String phone = resolveContactPhone(invoice.getContactId());
        String orgName = resolveOrgName(orgId);

        BigDecimal balanceDue = invoice.getBalanceDue() != null
                ? invoice.getBalanceDue() : invoice.getTotalAmount();

        String message = String.format(
                "Friendly reminder: %s due",
                formatAmount(balanceDue));
        if (invoice.getDueDate() != null) {
            message += " " + invoice.getDueDate().format(DATE_FMT);
        }
        message += "\n\nInvoice: " + invoice.getInvoiceNumber();
        message += "\nView: " + shareUrl;
        message += "\n\nFrom " + orgName;
        message += BRANDING;

        return buildResult(shareUrl, phone, message, invoice.getInvoiceNumber());
    }

    public Map<String, String> shareBill(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        PurchaseBill bill = purchaseBillRepository.findByIdAndOrgIdAndIsDeletedFalse(billId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Bill", billId));

        String shareUrl = buildShareUrl("bill", orgId, billId);
        String phone = resolveContactPhone(bill.getContactId());
        String orgName = resolveOrgName(orgId);

        String message = String.format(
                "Bill %s for %s",
                bill.getBillNumber(),
                formatAmount(bill.getTotalAmount()));
        if (bill.getDueDate() != null) {
            message += " due " + bill.getDueDate().format(DATE_FMT);
        }
        message += "\n\nView: " + shareUrl;
        message += "\n\nFrom " + orgName;
        message += BRANDING;

        return buildResult(shareUrl, phone, message, bill.getBillNumber());
    }

    public Map<String, String> shareEstimate(UUID estimateId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Estimate estimate = estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Estimate", estimateId));

        String shareUrl = buildShareUrl("estimate", orgId, estimateId);
        String phone = resolveContactPhone(estimate.getContactId());
        String orgName = resolveOrgName(orgId);

        String message = String.format(
                "Quote %s for your review",
                estimate.getEstimateNumber());
        message += "\nTotal: " + formatAmount(estimate.getTotal());
        message += "\n\nView: " + shareUrl;
        message += "\n\nFrom " + orgName;
        message += BRANDING;

        return buildResult(shareUrl, phone, message, estimate.getEstimateNumber());
    }

    // ── Helpers ─────────────────────────────────────────────────

    private String buildShareUrl(String docType, UUID orgId, UUID docId) {
        String token = Base64.getUrlEncoder().withoutPadding()
                .encodeToString((docType + ":" + orgId + ":" + docId)
                        .getBytes(StandardCharsets.UTF_8));
        return appBaseUrl + "/d/" + token;
    }

    private String resolveContactPhone(UUID contactId) {
        if (contactId == null) return "";
        return contactRepository.findById(contactId)
                .map(Contact::getPhone)
                .orElse("");
    }

    private String resolveOrgName(UUID orgId) {
        return organisationRepository.findById(orgId)
                .map(Organisation::getName)
                .orElse("your business");
    }

    private String formatAmount(BigDecimal amount) {
        if (amount == null) return "\u20B90.00";
        return "\u20B9" + amount.setScale(2, java.math.RoundingMode.HALF_UP).toPlainString();
    }

    private Map<String, String> buildResult(String shareUrl, String phone,
                                             String message, String docNumber) {
        Map<String, String> result = new LinkedHashMap<>();
        result.put("shareUrl", shareUrl);
        result.put("message", message);
        result.put("documentNumber", docNumber);
        if (phone != null && !phone.isBlank()) {
            result.put("phone", phone);
        }
        return result;
    }
}
