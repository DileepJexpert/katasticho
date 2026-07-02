package com.katasticho.erp.ar.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.posting.AccountingPostingEngine;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ar.dto.CustomerReceiptRequest;
import com.katasticho.erp.ar.dto.CustomerReceiptResponse;
import com.katasticho.erp.ar.entity.CustomerReceipt;
import com.katasticho.erp.ar.entity.CustomerReceiptAllocation;
import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.CustomerReceiptRepository;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.snapshot.DocumentSnapshotService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Customer receipt with multi-invoice allocation + customer advance.
 *
 * A receipt collects one lump sum from a customer, applies it across many open
 * invoices, and parks any unallocated excess as a Customer Advance (2100)
 * liability. The legacy single-invoice {@link PaymentService} path is untouched.
 *
 * On recordReceipt():
 *   DR Cash/Bank (by method)   = total received
 *   CR Accounts Receivable     = Σ allocations
 *   CR Customer Advance (2100)  = unallocated remainder
 *
 * All financial writes go through journalService.postJournal() via the posting
 * engine. The AR mirror of {@code com.katasticho.erp.ap.service.VendorPaymentService}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class CustomerReceiptService {

    private final CustomerReceiptRepository receiptRepository;
    private final InvoiceRepository invoiceRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final BranchRepository branchRepository;
    private final JournalService journalService;
    private final AccountingPostingEngine postingEngine;
    private final InvoiceService invoiceService;
    private final CurrencyService currencyService;
    private final CommentService commentService;
    private final DocumentSnapshotService documentSnapshotService;

    private static final Set<String> PAYABLE_STATUSES = Set.of("SENT", "PARTIALLY_PAID", "OVERDUE");

    @Transactional
    public CustomerReceiptResponse recordReceipt(CustomerReceiptRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));
        if (contact.getContactType() != ContactType.CUSTOMER && contact.getContactType() != ContactType.BOTH) {
            throw new BusinessException("Contact is not a customer",
                    "AR_CONTACT_NOT_CUSTOMER", HttpStatus.BAD_REQUEST);
        }

        // ── Validate allocations + collect per-invoice exchange rates ─────
        Set<UUID> seenInvoices = new HashSet<>();
        BigDecimal totalAllocated = BigDecimal.ZERO;
        List<AccountingPostingEngine.ArAllocationFx> allocationFx = new ArrayList<>();
        List<Invoice> lockedInvoices = new ArrayList<>();

        for (CustomerReceiptRequest.AllocationRequest alloc : request.allocations()) {
            if (!seenInvoices.add(alloc.invoiceId())) {
                throw new BusinessException(
                        "Invoice " + alloc.invoiceId() + " is allocated more than once",
                        "AR_RECEIPT_DUPLICATE_INVOICE", HttpStatus.BAD_REQUEST);
            }
            Invoice invoice = invoiceRepository.findLockedByIdAndOrgIdAndIsDeletedFalse(alloc.invoiceId(), orgId)
                    .orElseGet(() -> invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(alloc.invoiceId(), orgId)
                            .orElseThrow(() -> BusinessException.notFound("Invoice", alloc.invoiceId())));

            if (!PAYABLE_STATUSES.contains(invoice.getStatus())) {
                throw new BusinessException(
                        "Invoice " + invoice.getInvoiceNumber() + " is not payable (status: " + invoice.getStatus() + ")",
                        "AR_INVOICE_NOT_PAYABLE", HttpStatus.BAD_REQUEST);
            }
            if (alloc.amountApplied().compareTo(invoice.getBalanceDue()) > 0) {
                throw new BusinessException(
                        "Allocation " + alloc.amountApplied() + " exceeds balance due "
                                + invoice.getBalanceDue() + " on invoice " + invoice.getInvoiceNumber(),
                        "AR_RECEIPT_ALLOCATION_EXCEEDS_BALANCE", HttpStatus.BAD_REQUEST);
            }
            totalAllocated = totalAllocated.add(alloc.amountApplied());
            allocationFx.add(new AccountingPostingEngine.ArAllocationFx(
                    alloc.amountApplied(), invoice.getExchangeRate()));
            lockedInvoices.add(invoice);
        }

        // Advance = received − applied. The received amount must cover the
        // allocations; the excess is the customer's advance.
        BigDecimal advance = request.amount().subtract(totalAllocated);
        if (advance.signum() < 0) {
            throw new BusinessException(
                    "Allocations (" + totalAllocated + ") exceed the received amount (" + request.amount() + ")",
                    "AR_RECEIPT_OVER_ALLOCATED", HttpStatus.BAD_REQUEST);
        }

        // ── Exchange rate + receipt number ───────────────────────────────
        BigDecimal exchangeRate = currencyService.getRate(org.getBaseCurrency(), org.getBaseCurrency(), request.receiptDate());
        BigDecimal baseAmount = request.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);
        int periodYear = invoiceService.computeFiscalYear(request.receiptDate(), org.getFiscalYearStart());
        String receiptNumber = invoiceService.generateNumber(orgId, "RCPT", periodYear);

        // ── Post journal ─────────────────────────────────────────────────
        JournalEntry journalEntry = postingEngine.postCustomerReceipt(
                orgId, receiptNumber, request.receiptDate(),
                request.amount(), advance, request.paymentMethod(),
                exchangeRate, allocationFx);

        // ── Resolve branch ───────────────────────────────────────────────
        UUID branchId = request.branchId() != null
                ? request.branchId()
                : branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                        .map(Branch::getId).orElse(null);

        // ── Build receipt + allocations, settle each invoice ─────────────
        CustomerReceipt receipt = CustomerReceipt.builder()
                .orgId(orgId)
                .branchId(branchId)
                .contactId(contact.getId())
                .receiptNumber(receiptNumber)
                .receiptDate(request.receiptDate())
                .amount(request.amount())
                .allocatedAmount(totalAllocated)
                .advanceAmount(advance)
                .currency(org.getBaseCurrency())
                .exchangeRate(exchangeRate)
                .baseAmount(baseAmount)
                .paymentMethod(request.paymentMethod())
                .referenceNumber(request.referenceNumber())
                .notes(request.notes())
                .journalEntryId(journalEntry.getId())
                .createdBy(userId)
                .build();

        for (int i = 0; i < request.allocations().size(); i++) {
            CustomerReceiptRequest.AllocationRequest allocReq = request.allocations().get(i);
            Invoice invoice = lockedInvoices.get(i);

            receipt.addAllocation(CustomerReceiptAllocation.builder()
                    .invoiceId(allocReq.invoiceId())
                    .amountApplied(allocReq.amountApplied())
                    .build());

            invoiceService.updatePaymentStatus(invoice, allocReq.amountApplied());
            commentService.addSystemComment("INVOICE", invoice.getId(),
                    "Receipt " + receiptNumber + ": ₹" + allocReq.amountApplied()
                            + " applied (" + request.paymentMethod() + ")");
        }

        receipt = receiptRepository.save(receipt);

        // Reduce the customer's outstanding AR by the APPLIED amount only.
        // The advance is a 2100 liability, not a receivable reduction.
        if (totalAllocated.signum() > 0) {
            adjustContactOutstandingAr(contact, totalAllocated.negate());
        }

        log.info("Customer receipt {} recorded: {} across {} invoice(s), advance {}",
                receiptNumber, request.amount(), request.allocations().size(), advance);

        CustomerReceiptResponse response = toResponse(receipt);
        documentSnapshotService.createSnapshot("CUSTOMER_RECEIPT", receipt.getId(), receiptNumber, response);
        return response;
    }

    @Transactional
    public CustomerReceiptResponse voidReceipt(UUID receiptId, String reason) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomerReceipt receipt = receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .orElseThrow(() -> BusinessException.notFound("CustomerReceipt", receiptId));

        if (receipt.getJournalEntryId() != null) {
            journalService.reverseEntry(receipt.getJournalEntryId());
        }

        // Restore each invoice's balance.
        for (CustomerReceiptAllocation alloc : receipt.getAllocations()) {
            Invoice invoice = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(alloc.getInvoiceId(), orgId)
                    .orElse(null);
            if (invoice != null) {
                invoiceService.updatePaymentStatus(invoice, alloc.getAmountApplied().negate());
                commentService.addSystemComment("INVOICE", invoice.getId(),
                        "Receipt " + receipt.getReceiptNumber() + ": ₹" + alloc.getAmountApplied()
                                + " reversed (receipt voided)"
                                + (reason != null && !reason.isBlank() ? " — " + reason : ""));
            }
        }

        // Restore the customer's outstanding AR for the reversed allocations.
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(receipt.getContactId(), orgId)
                .orElse(null);
        if (contact != null && receipt.getAllocatedAmount().signum() > 0) {
            adjustContactOutstandingAr(contact, receipt.getAllocatedAmount());
        }

        receipt.setDeleted(true);
        receipt = receiptRepository.save(receipt);

        log.info("Customer receipt {} voided", receipt.getReceiptNumber());
        return toResponse(receipt);
    }

    // ── Queries ─────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public CustomerReceiptResponse getReceiptResponse(UUID receiptId) {
        return toResponse(getReceipt(receiptId));
    }

    public CustomerReceipt getReceipt(UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .orElseThrow(() -> BusinessException.notFound("CustomerReceipt", receiptId));
    }

    @Transactional(readOnly = true)
    public Page<CustomerReceiptResponse> listReceipts(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return receiptRepository.findByOrgIdAndIsDeletedFalseOrderByReceiptDateDesc(orgId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<CustomerReceiptResponse> listReceiptsByContact(UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return receiptRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByReceiptDateDesc(orgId, contactId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public List<CustomerReceiptResponse> listReceiptsForInvoice(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return receiptRepository.findByOrgIdAndInvoiceId(orgId, invoiceId)
                .stream().map(this::toResponse).toList();
    }

    /** Unallocated advance currently sitting on a customer (CoA 2100 sub-balance). */
    @Transactional(readOnly = true)
    public BigDecimal availableAdvance(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal advance = receiptRepository.sumAdvanceByContact(orgId, contactId);
        return advance != null ? advance : BigDecimal.ZERO;
    }

    // ── Helpers ─────────────────────────────────────────────────

    private void adjustContactOutstandingAr(Contact contact, BigDecimal delta) {
        if (delta == null || delta.compareTo(BigDecimal.ZERO) == 0) return;
        BigDecimal current = contact.getOutstandingAr() != null ? contact.getOutstandingAr() : BigDecimal.ZERO;
        contact.setOutstandingAr(current.add(delta).max(BigDecimal.ZERO));
        contactRepository.save(contact);
    }

    public CustomerReceiptResponse toResponse(CustomerReceipt receipt) {
        Contact contact = contactRepository.findById(receipt.getContactId()).orElse(null);

        List<CustomerReceiptResponse.AllocationResponse> allocResponses = receipt.getAllocations().stream()
                .map(a -> {
                    Invoice invoice = invoiceRepository.findById(a.getInvoiceId()).orElse(null);
                    return new CustomerReceiptResponse.AllocationResponse(
                            a.getId(), a.getInvoiceId(),
                            invoice != null ? invoice.getInvoiceNumber() : null,
                            a.getAmountApplied());
                })
                .toList();

        return new CustomerReceiptResponse(
                receipt.getId(), receipt.getContactId(),
                contact != null ? contact.getDisplayName() : null,
                receipt.getReceiptNumber(), receipt.getReceiptDate(),
                receipt.getAmount(), receipt.getAllocatedAmount(), receipt.getAdvanceAmount(),
                receipt.getCurrency(), receipt.getPaymentMethod(),
                receipt.getReferenceNumber(), receipt.getNotes(),
                receipt.getJournalEntryId(), allocResponses, receipt.getCreatedAt());
    }
}
