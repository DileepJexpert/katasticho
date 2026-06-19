package com.katasticho.erp.portal.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.dto.ContactLedgerResponse;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.contact.service.ContactLedgerService;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.repository.PortalUserRepository;
import com.katasticho.erp.procurement.entity.PurchaseOrder;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Read-only data for a logged-in portal user, scoped to THEIR contact only.
 * The portal filter sets {@code TenantContext} (orgId + userId=portalUserId);
 * this resolves the {@link PortalUser} to get the contact and kind, then serves
 * customer (invoices/outstanding/ledger) or vendor (POs/bills) data.
 */
@Service
@RequiredArgsConstructor
public class PortalDataService {

    private final PortalUserRepository portalUserRepository;
    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;
    private final PurchaseBillRepository purchaseBillRepository;
    private final PurchaseOrderRepository purchaseOrderRepository;
    private final ContactLedgerService contactLedgerService;

    @Transactional(readOnly = true)
    public Map<String, Object> me() {
        PortalUser pu = current();
        Contact contact = contact(pu);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("kind", pu.getKind());
        out.put("email", pu.getEmail());
        out.put("fullName", pu.getFullName());
        out.put("contact", contactSummary(contact));
        return out;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> dashboard() {
        PortalUser pu = current();
        if ("VENDOR".equals(pu.getKind())) {
            return vendorDashboard(pu);
        }
        return customerDashboard(pu);
    }

    // ── Customer ─────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> invoices() {
        PortalUser pu = customerOnly();
        return invoiceRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 100))
                .getContent().stream().map(this::invoiceRow).toList();
    }

    @Transactional(readOnly = true)
    public ContactLedgerResponse statement(LocalDate from, LocalDate to) {
        PortalUser pu = customerOnly();
        return contactLedgerService.getLedger(pu.getContactId(), from, to);
    }

    private Map<String, Object> customerDashboard(PortalUser pu) {
        List<Invoice> invoices = invoiceRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 500))
                .getContent();
        BigDecimal outstanding = BigDecimal.ZERO;
        int openCount = 0;
        for (Invoice inv : invoices) {
            BigDecimal bal = nz(inv.getBalanceDue());
            if (bal.signum() > 0) openCount++;
            outstanding = outstanding.add(bal);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("kind", "CUSTOMER");
        out.put("outstanding", outstanding);
        out.put("openInvoiceCount", openCount);
        out.put("totalInvoiceCount", invoices.size());
        out.put("recentInvoices", invoices.stream().limit(5).map(this::invoiceRow).toList());
        return out;
    }

    // ── Vendor ───────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<Map<String, Object>> purchaseOrders() {
        PortalUser pu = vendorOnly();
        return purchaseOrderRepository
                .findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByCreatedAtDesc(pu.getOrgId(), pu.getContactId())
                .stream().map(this::poRow).toList();
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> bills() {
        PortalUser pu = vendorOnly();
        return purchaseBillRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 100))
                .getContent().stream().map(this::billRow).toList();
    }

    private Map<String, Object> vendorDashboard(PortalUser pu) {
        List<PurchaseOrder> pos = purchaseOrderRepository
                .findByOrgIdAndSupplierIdAndIsDeletedFalseOrderByCreatedAtDesc(pu.getOrgId(), pu.getContactId());
        List<PurchaseBill> billList = purchaseBillRepository
                .findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(
                        pu.getOrgId(), pu.getContactId(), PageRequest.of(0, 500))
                .getContent();
        BigDecimal payable = BigDecimal.ZERO;
        int unpaid = 0;
        for (PurchaseBill b : billList) {
            BigDecimal bal = nz(b.getBalanceDue());
            if (bal.signum() > 0) unpaid++;
            payable = payable.add(bal);
        }
        long openPos = pos.stream()
                .filter(p -> !"CANCELLED".equalsIgnoreCase(p.getStatus())
                        && !"CLOSED".equalsIgnoreCase(p.getStatus())
                        && !"COMPLETED".equalsIgnoreCase(p.getStatus()))
                .count();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("kind", "VENDOR");
        out.put("payableToYou", payable);
        out.put("unpaidBillCount", unpaid);
        out.put("openPurchaseOrderCount", openPos);
        out.put("recentPurchaseOrders", pos.stream().limit(5).map(this::poRow).toList());
        return out;
    }

    // ── Row mappers ──────────────────────────────────────────────────────

    private Map<String, Object> invoiceRow(Invoice inv) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", inv.getId());
        m.put("number", inv.getInvoiceNumber());
        m.put("date", inv.getInvoiceDate());
        m.put("dueDate", inv.getDueDate());
        m.put("total", nz(inv.getTotalAmount()));
        m.put("balanceDue", nz(inv.getBalanceDue()));
        m.put("status", inv.getStatus());
        return m;
    }

    private Map<String, Object> billRow(PurchaseBill b) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", b.getId());
        m.put("number", b.getBillNumber());
        m.put("vendorBillNumber", b.getVendorBillNumber());
        m.put("date", b.getBillDate());
        m.put("dueDate", b.getDueDate());
        m.put("total", nz(b.getTotalAmount()));
        m.put("balanceDue", nz(b.getBalanceDue()));
        m.put("status", b.getStatus());
        return m;
    }

    private Map<String, Object> poRow(PurchaseOrder p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("number", p.getPoNumber());
        m.put("date", p.getOrderDate());
        m.put("total", nz(p.getTotalAmount()));
        m.put("status", p.getStatus());
        return m;
    }

    private Map<String, Object> contactSummary(Contact c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.getId());
        m.put("displayName", c.getDisplayName());
        m.put("email", c.getEmail());
        m.put("phone", c.getPhone() != null ? c.getPhone() : c.getMobile());
        return m;
    }

    // ── Scoping helpers ──────────────────────────────────────────────────

    private PortalUser current() {
        UUID portalUserId = TenantContext.getCurrentUserId();
        return portalUserRepository.findByIdAndIsDeletedFalse(portalUserId)
                .filter(p -> "ACTIVE".equals(p.getStatus()))
                .orElseThrow(() -> new BusinessException("Portal session is invalid",
                        "PORTAL_SESSION_INVALID", HttpStatus.UNAUTHORIZED));
    }

    private PortalUser customerOnly() {
        PortalUser pu = current();
        if (!"CUSTOMER".equals(pu.getKind())) {
            throw new BusinessException("Not available for vendor accounts",
                    "PORTAL_WRONG_KIND", HttpStatus.FORBIDDEN);
        }
        return pu;
    }

    private PortalUser vendorOnly() {
        PortalUser pu = current();
        if (!"VENDOR".equals(pu.getKind())) {
            throw new BusinessException("Not available for customer accounts",
                    "PORTAL_WRONG_KIND", HttpStatus.FORBIDDEN);
        }
        return pu;
    }

    private Contact contact(PortalUser pu) {
        return contactRepository.findByIdAndOrgIdAndIsDeletedFalse(pu.getContactId(), pu.getOrgId())
                .orElseThrow(() -> BusinessException.notFound("Contact", pu.getContactId()));
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
