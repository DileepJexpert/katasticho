package com.katasticho.erp.contact.service;

import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.dto.ContactLedgerResponse;
import com.katasticho.erp.contact.dto.ContactLedgerResponse.LedgerEntry;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
public class ContactLedgerService {

    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;
    private final PaymentRepository paymentRepository;
    private final PurchaseBillRepository billRepository;
    private final VendorPaymentRepository vendorPaymentRepository;

    @Transactional(readOnly = true)
    public ContactLedgerResponse getLedger(UUID contactId, LocalDate startDate, LocalDate endDate) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Contact contact = contactRepository.findById(contactId)
                .filter(c -> c.getOrgId().equals(orgId) && !c.isDeleted())
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));

        boolean isCustomer = "CUSTOMER".equals(contact.getContactType().name());

        List<LedgerEntry> entries = new ArrayList<>();
        BigDecimal totalInvoiced = BigDecimal.ZERO;
        BigDecimal totalPaid = BigDecimal.ZERO;

        if (isCustomer) {
            List<Invoice> invoices = invoiceRepository
                    .findByOrgIdAndContactIdAndIsDeletedFalseOrderByInvoiceDateDesc(orgId, contactId, Pageable.unpaged())
                    .getContent();

            for (Invoice inv : invoices) {
                if ("DRAFT".equals(inv.getStatus()) || "CANCELLED".equals(inv.getStatus())) continue;
                if (inv.getInvoiceDate().isBefore(startDate) || inv.getInvoiceDate().isAfter(endDate)) continue;

                entries.add(new LedgerEntry(
                        inv.getInvoiceDate(), "INVOICE", inv.getInvoiceNumber(), inv.getId(),
                        "Invoice " + inv.getInvoiceNumber(),
                        inv.getTotalAmount(), BigDecimal.ZERO, BigDecimal.ZERO));
                totalInvoiced = totalInvoiced.add(inv.getTotalAmount());
            }

            List<Payment> payments = paymentRepository
                    .findByOrgIdAndIsDeletedFalseOrderByPaymentDateDesc(orgId, Pageable.unpaged())
                    .getContent().stream()
                    .filter(p -> p.getContactId().equals(contactId))
                    .toList();

            for (Payment pay : payments) {
                if (pay.getPaymentDate().isBefore(startDate) || pay.getPaymentDate().isAfter(endDate)) continue;

                entries.add(new LedgerEntry(
                        pay.getPaymentDate(), "PAYMENT", pay.getPaymentNumber(), pay.getId(),
                        "Payment received (" + pay.getPaymentMethod() + ")",
                        BigDecimal.ZERO, pay.getAmount(), BigDecimal.ZERO));
                totalPaid = totalPaid.add(pay.getAmount());
            }
        } else {
            List<PurchaseBill> bills = billRepository
                    .findByOrgIdAndContactIdAndIsDeletedFalseOrderByBillDateDesc(orgId, contactId, Pageable.unpaged())
                    .getContent();

            for (PurchaseBill bill : bills) {
                if ("DRAFT".equals(bill.getStatus()) || "CANCELLED".equals(bill.getStatus())) continue;
                if (bill.getBillDate().isBefore(startDate) || bill.getBillDate().isAfter(endDate)) continue;

                entries.add(new LedgerEntry(
                        bill.getBillDate(), "BILL", bill.getBillNumber(), bill.getId(),
                        "Bill " + bill.getBillNumber(),
                        BigDecimal.ZERO, bill.getTotalAmount(), BigDecimal.ZERO));
                totalInvoiced = totalInvoiced.add(bill.getTotalAmount());
            }

            List<VendorPayment> vPayments = vendorPaymentRepository
                    .findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId);

            for (VendorPayment vp : vPayments) {
                if (vp.getPaymentDate().isBefore(startDate) || vp.getPaymentDate().isAfter(endDate)) continue;

                entries.add(new LedgerEntry(
                        vp.getPaymentDate(), "VENDOR_PAYMENT", vp.getPaymentNumber(), vp.getId(),
                        "Payment made (" + vp.getPaymentMode() + ")",
                        vp.getAmount(), BigDecimal.ZERO, BigDecimal.ZERO));
                totalPaid = totalPaid.add(vp.getAmount());
            }
        }

        entries.sort(Comparator.comparing(LedgerEntry::date).thenComparing(LedgerEntry::type));

        BigDecimal openingBalance = contact.getOpeningBalance() != null ? contact.getOpeningBalance() : BigDecimal.ZERO;
        BigDecimal running = openingBalance;
        List<LedgerEntry> withRunning = new ArrayList<>();

        for (LedgerEntry e : entries) {
            if (isCustomer) {
                running = running.add(e.debit()).subtract(e.credit());
            } else {
                running = running.add(e.credit()).subtract(e.debit());
            }
            withRunning.add(new LedgerEntry(
                    e.date(), e.type(), e.number(), e.referenceId(),
                    e.description(), e.debit(), e.credit(), running));
        }

        return new ContactLedgerResponse(
                contactId, contact.getDisplayName(),
                contact.getContactType().name(),
                openingBalance, running,
                totalInvoiced, totalPaid, withRunning);
    }
}
