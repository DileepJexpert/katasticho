package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.PaymentResponse;
import com.katasticho.erp.ar.dto.RecordPaymentForInvoiceRequest;
import com.katasticho.erp.ar.dto.RecordPaymentRequest;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.entity.Payment;
import com.katasticho.erp.ar.entity.PaymentStatus;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.ar.repository.PaymentRepository;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.common.workflow.ApprovalWorkflowService;
import com.katasticho.erp.common.workflow.DocumentStateEngine;
import com.katasticho.erp.common.workflow.WorkflowDefinition;
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
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.Optional;
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
    private final AccountingPostingEngine postingEngine;
    private final InvoiceService invoiceService;
    private final CurrencyService currencyService;
    private final AuditService auditService;
    private final CommentService commentService;
    private final DocumentSnapshotService documentSnapshotService;
    private final com.katasticho.erp.common.event.DomainEventPublisher domainEventPublisher;
    private final ApprovalWorkflowService approvalWorkflowService;
    private final DocumentStateEngine documentStateEngine;

    /**
     * Record a payment against an invoice (supports partial payments).
     */
    @Transactional
    public Payment recordPayment(RecordPaymentRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Invoice invoice = findInvoiceForPayment(request.invoiceId(), orgId);

        // Validate invoice is payable
        if ("DRAFT".equals(invoice.getStatus()) || "CANCELLED".equals(invoice.getStatus())
                || "PAID".equals(invoice.getStatus())) {
            throw new BusinessException("Invoice " + invoice.getInvoiceNumber() + " is not payable (status: " + invoice.getStatus() + ")",
                    "AR_INVOICE_NOT_PAYABLE", HttpStatus.BAD_REQUEST);
        }

        // Validate amount doesn't exceed balance
        requirePaymentWithinAvailableBalance(invoice, request.amount());

        // Exchange rate
        BigDecimal exchangeRate = currencyService.getRate(org.getBaseCurrency(), org.getBaseCurrency(), request.paymentDate());
        BigDecimal baseAmount = request.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

        // Generate payment number
        int periodYear = invoiceService.computeFiscalYear(request.paymentDate(), org.getFiscalYearStart());
        String paymentNumber = invoiceService.generateNumber(orgId, "PAY", periodYear);

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
                .currency(org.getBaseCurrency())
                .exchangeRate(exchangeRate)
                .baseAmount(baseAmount)
                .paymentMethod(request.paymentMethod())
                .referenceNumber(request.referenceNumber())
                .bankAccount(request.bankAccount())
                .notes(request.notes())
                .status(PaymentStatus.DRAFT)
                .createdBy(userId)
                .build();

        payment = paymentRepository.save(payment);

        PaymentApprovalDecision approvalDecision = evaluateApproval(orgId, payment, invoice);
        if (approvalDecision.requiresApproval()) {
            documentStateEngine.validateTransition(orgId, "PAYMENT", payment.getStatus().name(), PaymentStatus.PENDING_APPROVAL.name());
            payment.setStatus(PaymentStatus.PENDING_APPROVAL);
            payment = paymentRepository.save(payment);
            approvalWorkflowService.requestApproval(
                    orgId,
                    approvalDecision.workflow(),
                    "PAYMENT",
                    payment.getId(),
                    approvalDecision.reason(),
                    approvalDecision.context());
            commentService.addSystemComment("INVOICE", invoice.getId(),
                    "Payment of \u20b9" + payment.getAmount() + " is pending approval (" + payment.getPaymentMethod() + ")");
            documentSnapshotService.createSnapshot("PAYMENT", payment.getId(), payment.getPaymentNumber(), toResponse(payment));
            log.info("Payment {} pending approval: {} for invoice {}", payment.getPaymentNumber(),
                    payment.getAmount(), invoice.getInvoiceNumber());
            return payment;
        }

        return postPayment(payment.getId());
    }

    @Transactional
    public Payment postPayment(UUID paymentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Payment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Payment", paymentId));

        if (payment.getStatus() == PaymentStatus.POSTED) {
            throw new BusinessException("Payment " + payment.getPaymentNumber() + " is already posted",
                    "AR_PAYMENT_ALREADY_POSTED", HttpStatus.BAD_REQUEST);
        }
        if (payment.getStatus() == PaymentStatus.VOIDED) {
            throw new BusinessException("Payment " + payment.getPaymentNumber() + " is voided and cannot be posted",
                    "AR_PAYMENT_VOIDED", HttpStatus.BAD_REQUEST);
        }
        if (payment.getStatus() != PaymentStatus.DRAFT && payment.getStatus() != PaymentStatus.PENDING_APPROVAL) {
            throw new BusinessException("Payment " + payment.getPaymentNumber() + " cannot be posted from status " + payment.getStatus(),
                    "AR_PAYMENT_INVALID_STATUS", HttpStatus.BAD_REQUEST);
        }

        UUID invoiceId = payment.getInvoiceId();
        Invoice invoice = findInvoiceForPayment(invoiceId, orgId);

        if (payment.getStatus() == PaymentStatus.PENDING_APPROVAL) {
            documentStateEngine.validateTransition(orgId, "PAYMENT", PaymentStatus.PENDING_APPROVAL.name(), PaymentStatus.POSTED.name());
        } else {
            documentStateEngine.validateTransition(orgId, "PAYMENT", PaymentStatus.DRAFT.name(), PaymentStatus.POSTED.name());
        }
        requirePaymentWithinCurrentBalance(invoice, payment.getAmount());

        JournalEntry journalEntry = postingEngine.postPaymentReceived(
                orgId, payment.getPaymentNumber(), invoice.getInvoiceNumber(),
                payment.getPaymentDate(), payment.getAmount(), payment.getPaymentMethod(),
                invoice.getExchangeRate(), payment.getExchangeRate());

        payment.setJournalEntryId(journalEntry.getId());
        payment.setStatus(PaymentStatus.POSTED);
        payment.setPostedAt(Instant.now());
        payment.setPostedBy(userId);
        payment = paymentRepository.save(payment);

        invoiceService.updatePaymentStatus(invoice, payment.getAmount());
        // NOTE: contact.outstanding_ar is the KHATA (invoice-less) ledger only \u2014
        // it is maintained solely by the POS credit-sale + khata-settlement paths.
        // Invoice-backed AR lives in the invoice's balanceDue and is served by the
        // computed outstanding cache, so an invoice payment must NOT touch this
        // column (doing so mints phantom khata on void and erases real khata here).

        commentService.addSystemComment("INVOICE", invoice.getId(),
                "Payment of \u20b9" + payment.getAmount() + " received (" + payment.getPaymentMethod() + ")");

        auditService.log("PAYMENT", payment.getId(), "CREATE", null,
                "{\"paymentNumber\":\"" + payment.getPaymentNumber()
                        + "\",\"amount\":\"" + payment.getAmount()
                        + "\",\"invoice\":\"" + invoice.getInvoiceNumber() + "\"}");
        documentSnapshotService.createSnapshot("PAYMENT", payment.getId(), payment.getPaymentNumber(), toResponse(payment));
        domainEventPublisher.publish("PAYMENT_RECORDED", "PAYMENT", payment.getId(), java.util.Map.of(
                "paymentNumber", payment.getPaymentNumber(),
                "amount", payment.getAmount(),
                "paymentMethod", payment.getPaymentMethod(),
                "invoiceNumber", invoice.getInvoiceNumber()));

        log.info("Payment {} posted: {} for invoice {}", payment.getPaymentNumber(),
                payment.getAmount(), invoice.getInvoiceNumber());
        return payment;
    }

    @Transactional
    public Payment voidPayment(UUID paymentId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        Payment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Payment", paymentId));

        if (payment.getStatus() == PaymentStatus.DRAFT || payment.getStatus() == PaymentStatus.PENDING_APPROVAL) {
            return voidPendingPayment(paymentId, reason);
        }
        if (payment.getStatus() == PaymentStatus.VOIDED) {
            throw new BusinessException("Payment " + payment.getPaymentNumber() + " is already voided",
                    "AR_PAYMENT_ALREADY_VOIDED", HttpStatus.BAD_REQUEST);
        }
        if (payment.getStatus() != PaymentStatus.POSTED) {
            throw new BusinessException("Payment " + payment.getPaymentNumber() + " cannot be voided from status " + payment.getStatus(),
                    "AR_PAYMENT_INVALID_VOID_STATUS", HttpStatus.BAD_REQUEST);
        }
        if (payment.getJournalEntryId() == null) {
            throw new BusinessException("Posted payment has no journal entry to reverse",
                    "AR_PAYMENT_JOURNAL_MISSING", HttpStatus.BAD_REQUEST);
        }

        UUID invoiceId = payment.getInvoiceId();
        Invoice invoice = findInvoiceForPayment(invoiceId, orgId);

        journalService.reverseEntry(payment.getJournalEntryId());
        invoiceService.updatePaymentStatus(invoice, payment.getAmount().negate());
        // Symmetric with postPayment: the invoice's balanceDue is restored above;
        // contact.outstanding_ar (khata ledger) is intentionally left untouched.

        payment.setStatus(PaymentStatus.VOIDED);
        payment.setVoidReason(reason);
        payment.setVoidedAt(Instant.now());
        payment.setVoidedBy(userId);
        payment = paymentRepository.save(payment);

        commentService.addSystemComment("INVOICE", invoice.getId(),
                "Payment of ₹" + payment.getAmount() + " voided"
                        + (reason != null && !reason.isBlank() ? " (" + reason + ")" : ""));
        auditService.log("PAYMENT", payment.getId(), "VOID",
                "{\"status\":\"POSTED\"}",
                "{\"status\":\"VOIDED\",\"reason\":\"" + (reason != null ? reason : "") + "\"}");
        documentSnapshotService.createSnapshot("PAYMENT", payment.getId(), payment.getPaymentNumber(), toResponse(payment));
        return payment;
    }

    @Transactional
    public Payment voidPendingPayment(UUID paymentId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        Payment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Payment", paymentId));
        if (payment.getStatus() != PaymentStatus.PENDING_APPROVAL && payment.getStatus() != PaymentStatus.DRAFT) {
            throw new BusinessException("Only draft or pending approval payments can be voided without reversal",
                    "AR_PAYMENT_VOID_REQUIRES_DRAFT_OR_PENDING", HttpStatus.BAD_REQUEST);
        }
        if (payment.getStatus() == PaymentStatus.PENDING_APPROVAL) {
            documentStateEngine.validateTransition(orgId, "PAYMENT", PaymentStatus.PENDING_APPROVAL.name(), PaymentStatus.VOIDED.name());
        }
        payment.setStatus(PaymentStatus.VOIDED);
        payment.setVoidReason(reason);
        payment.setVoidedAt(Instant.now());
        payment.setVoidedBy(userId);
        payment = paymentRepository.save(payment);
        documentSnapshotService.createSnapshot("PAYMENT", payment.getId(), payment.getPaymentNumber(), toResponse(payment));
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

    @Transactional
    public PaymentResponse recordForInvoice(UUID invoiceId, RecordPaymentForInvoiceRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();

        Invoice invoice = findInvoiceForPayment(invoiceId, orgId);

        if (!List.of("SENT", "PARTIALLY_PAID", "OVERDUE").contains(invoice.getStatus())) {
            throw new BusinessException(
                    "Invoice " + invoice.getInvoiceNumber() + " is not payable (status: " + invoice.getStatus() + ")",
                    "AR_INVOICE_NOT_PAYABLE", HttpStatus.BAD_REQUEST);
        }

        requirePaymentWithinAvailableBalance(invoice, req.amount());

        RecordPaymentRequest internal = new RecordPaymentRequest(
                invoiceId, invoice.getContactId(), req.paymentDate(), req.amount(),
                req.paymentMethod(), req.referenceNumber(), null, req.notes());

        Payment payment = recordPayment(internal);
        return toResponse(payment);
    }

    public List<PaymentResponse> listForInvoice(UUID invoiceId) {
        return getPaymentsForInvoice(invoiceId).stream()
                .map(this::toResponse).toList();
    }

    public List<Payment> getPaymentsForInvoice(UUID invoiceId) {
        // Org-scope: the endpoints only carry an invoice UUID, so filter by the
        // caller's org to prevent cross-tenant reads of another org's payments.
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByOrgIdAndInvoiceIdAndIsDeletedFalse(orgId, invoiceId);
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
                p.getStatus() != null ? p.getStatus().name() : null,
                p.getJournalEntryId(), p.getPostedAt(), p.getCreatedAt());
    }

    private PaymentApprovalDecision evaluateApproval(UUID orgId, Payment payment, Invoice invoice) {
        Map<String, Object> context = paymentApprovalContext(payment, invoice);
        Optional<WorkflowDefinition> workflow = approvalWorkflowService.findMatchingWorkflow(orgId, "PAYMENT", context);
        return workflow
                .map(definition -> PaymentApprovalDecision.approval(
                        definition,
                        paymentApprovalReason(definition, payment, context),
                        context))
                .orElseGet(PaymentApprovalDecision::none);
    }

    private Invoice findInvoiceForPayment(UUID invoiceId, UUID orgId) {
        Optional<Invoice> locked = invoiceRepository.findLockedByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId);
        if (locked != null && locked.isPresent()) {
            return locked.get();
        }
        return invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
    }

    private void requirePaymentWithinAvailableBalance(Invoice invoice, BigDecimal amount) {
        BigDecimal pendingAmount = paymentRepository.sumPaymentsByInvoiceAndStatuses(
                invoice.getId(), List.of(PaymentStatus.PENDING_APPROVAL));
        if (pendingAmount == null) {
            pendingAmount = BigDecimal.ZERO;
        }
        BigDecimal available = invoice.getBalanceDue().subtract(pendingAmount);
        if (amount.compareTo(available) > 0) {
            throw new BusinessException(
                    "Payment amount " + amount + " exceeds available balance " + available
                            + " after pending payments " + pendingAmount,
                    "AR_PAYMENT_EXCEEDS_BALANCE", HttpStatus.BAD_REQUEST);
        }
    }

    private void requirePaymentWithinCurrentBalance(Invoice invoice, BigDecimal amount) {
        if (amount.compareTo(invoice.getBalanceDue()) > 0) {
            throw new BusinessException(
                    "Payment amount " + amount + " exceeds balance due " + invoice.getBalanceDue(),
                    "AR_PAYMENT_EXCEEDS_BALANCE", HttpStatus.BAD_REQUEST);
        }
    }

    private Map<String, Object> paymentApprovalContext(Payment payment, Invoice invoice) {
        long daysBackdated = Math.max(0, ChronoUnit.DAYS.between(payment.getPaymentDate(), LocalDate.now()));
        return Map.of(
                "payment.amount", payment.getAmount(),
                "payment.paymentDate", payment.getPaymentDate().toString(),
                "payment.daysBackdated", daysBackdated,
                "payment.method", payment.getPaymentMethod(),
                "invoice.balanceDue", invoice.getBalanceDue(),
                "invoice.number", invoice.getInvoiceNumber()
        );
    }

    private String paymentApprovalReason(WorkflowDefinition workflow, Payment payment, Map<String, Object> context) {
        if ("PAYMENT_BACKDATED_APPROVAL".equals(workflow.getCode())) {
            return "Payment " + payment.getPaymentNumber() + " is backdated by "
                    + context.get("payment.daysBackdated") + " day(s)";
        }
        if ("PAYMENT_HIGH_VALUE_APPROVAL".equals(workflow.getCode())) {
            return "Payment " + payment.getPaymentNumber() + " amount " + payment.getAmount()
                    + " requires approval";
        }
        return "Payment " + payment.getPaymentNumber() + " requires approval";
    }

    private record PaymentApprovalDecision(
            WorkflowDefinition workflow,
            String reason,
            Map<String, Object> context
    ) {
        static PaymentApprovalDecision none() {
            return new PaymentApprovalDecision(null, null, Map.of());
        }

        static PaymentApprovalDecision approval(WorkflowDefinition workflow, String reason, Map<String, Object> context) {
            return new PaymentApprovalDecision(workflow, reason, context);
        }

        boolean requiresApproval() {
            return workflow != null;
        }
    }

}
