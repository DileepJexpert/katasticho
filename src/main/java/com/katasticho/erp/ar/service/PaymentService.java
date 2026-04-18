package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.currency.CurrencyService;
import com.katasticho.erp.organisation.Branch;
import com.katasticho.erp.organisation.BranchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

/**
 * Payment recording with partial payment support.
 *
 * On recordPayment():
 *   DR Cash/Bank (1010/1020) = payment amount
 *   CR Accounts Receivable (1200) = payment amount
 *
 * All financial writes go through journalService.postJournal().
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final BranchRepository branchRepository;
    private final JournalService journalService;
    private final InvoiceService invoiceService;
    private final CurrencyService currencyService;
    private final AuditService auditService;
    private final CommentService commentService;
    private final DefaultAccountService defaultAccountService;

    /**
     * Record a payment against an invoice (supports partial payments).
     */
    @Transactional
    public Payment recordPayment(RecordPaymentRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(request.invoiceId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", request.invoiceId()));

        // Validate invoice is payable
        if ("DRAFT".equals(invoice.getStatus()) || "CANCELLED".equals(invoice.getStatus())
                || "PAID".equals(invoice.getStatus())) {
            throw new BusinessException("Invoice " + invoice.getInvoiceNumber() + " is not payable (status: " + invoice.getStatus() + ")",
                    "AR_INVOICE_NOT_PAYABLE", HttpStatus.BAD_REQUEST);
        }

        // Validate amount doesn't exceed balance
        if (request.amount().compareTo(invoice.getBalanceDue()) > 0) {
            throw new BusinessException(
                    "Payment amount " + request.amount() + " exceeds balance due " + invoice.getBalanceDue(),
                    "AR_PAYMENT_EXCEEDS_BALANCE", HttpStatus.BAD_REQUEST);
        }

        // Exchange rate
        BigDecimal exchangeRate = currencyService.getRate("INR", org.getBaseCurrency(), request.paymentDate());
        BigDecimal baseAmount = request.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

        // Generate payment number
        int periodYear = invoiceService.computeFiscalYear(request.paymentDate(), org.getFiscalYearStart());
        String paymentNumber = invoiceService.generateNumber(orgId, "PAY", periodYear);

        // Determine debit account: CASH for cash/UPI, BANK for bank transfer/cheque/card
        String debitAccountCode = resolvePaymentAccount(orgId, request.paymentMethod());

        // Post journal: DR Cash/Bank, CR AR (per-org defaults)
        List<JournalLineRequest> journalLines = List.of(
                new JournalLineRequest(
                        debitAccountCode,
                        request.amount(), BigDecimal.ZERO,
                        "Payment " + paymentNumber + " received",
                        null, null),
                new JournalLineRequest(
                        defaultAccountService.getCode(orgId, DefaultAccountPurpose.AR),
                        BigDecimal.ZERO, request.amount(),
                        "AR cleared: " + invoice.getInvoiceNumber(),
                        null, null)
        );

        JournalPostRequest journalRequest = new JournalPostRequest(
                request.paymentDate(),
                "Payment " + paymentNumber + " for " + invoice.getInvoiceNumber(),
                "AR",
                null, // will be set after payment is saved
                journalLines,
                true);

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

        // Resolve contactId: prefer explicit value, else inherit from invoice
        UUID resolvedContactId = request.contactId() != null ? request.contactId() : invoice.getContactId();

        // Payment rolls up to the same branch as the invoice it settles.
        // Fall back to the org's default branch for pre-branch invoices.
        UUID branchId = invoice.getBranchId() != null
                ? invoice.getBranchId()
                : branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                        .map(Branch::getId).orElse(null);

        // Create payment record
        Payment payment = Payment.builder()
                .orgId(orgId)
                .branchId(branchId)
                .contactId(resolvedContactId)
                .invoiceId(invoice.getId())
                .paymentNumber(paymentNumber)
                .paymentDate(request.paymentDate())
                .amount(request.amount())
                .currency("INR")
                .exchangeRate(exchangeRate)
                .baseAmount(baseAmount)
                .paymentMethod(request.paymentMethod())
                .referenceNumber(request.referenceNumber())
                .bankAccount(request.bankAccount())
                .notes(request.notes())
                .journalEntryId(journalEntry.getId())
                .createdBy(userId)
                .build();

        payment = paymentRepository.save(payment);

        // Update invoice payment status
        invoiceService.updatePaymentStatus(invoice, request.amount());

        // System comment on the invoice timeline
        commentService.addSystemComment("INVOICE", invoice.getId(),
                "Payment of \u20b9" + payment.getAmount() + " received (" + payment.getPaymentMethod() + ")");

        auditService.log("PAYMENT", payment.getId(), "CREATE", null,
                "{\"paymentNumber\":\"" + payment.getPaymentNumber()
                        + "\",\"amount\":\"" + payment.getAmount()
                        + "\",\"invoice\":\"" + invoice.getInvoiceNumber() + "\"}");

        log.info("Payment {} recorded: {} for invoice {}", payment.getPaymentNumber(),
                payment.getAmount(), invoice.getInvoiceNumber());
        return payment;
    }

    public Payment getPayment(UUID paymentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Payment", paymentId));
    }

    public Page<Payment> listPayments(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByOrgIdAndIsDeletedFalseOrderByPaymentDateDesc(orgId, pageable);
    }

    public List<Payment> getPaymentsForInvoice(UUID invoiceId) {
        return paymentRepository.findByInvoiceIdAndIsDeletedFalse(invoiceId);
    }

    public PaymentResponse toResponse(Payment p) {
        Contact contact = contactRepository.findById(p.getContactId()).orElse(null);
        Invoice invoice = invoiceRepository.findById(p.getInvoiceId()).orElse(null);

        return new PaymentResponse(
                p.getId(), p.getContactId(),
                contact != null ? contact.getDisplayName() : null,
                p.getInvoiceId(),
                invoice != null ? invoice.getInvoiceNumber() : null,
                p.getPaymentNumber(), p.getPaymentDate(),
                p.getAmount(), p.getCurrency(), p.getPaymentMethod(),
                p.getReferenceNumber(), p.getBankAccount(), p.getNotes(),
                p.getJournalEntryId(), p.getCreatedAt());
    }

    private String resolvePaymentAccount(UUID orgId, String paymentMethod) {
        DefaultAccountPurpose purpose = switch (paymentMethod) {
            case "CASH", "UPI" -> DefaultAccountPurpose.CASH;
            case "BANK_TRANSFER", "CHEQUE", "CARD" -> DefaultAccountPurpose.BANK;
            default -> DefaultAccountPurpose.CASH;
        };
        return defaultAccountService.getCode(orgId, purpose);
    }
}
