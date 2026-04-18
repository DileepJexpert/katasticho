package com.katasticho.erp.ap.service;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.dto.JournalLineRequest;
import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.ap.dto.VendorPaymentRequest;
import com.katasticho.erp.ap.dto.VendorPaymentResponse;
import com.katasticho.erp.ap.entity.PurchaseBill;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.entity.VendorPaymentAllocation;
import com.katasticho.erp.ap.repository.PurchaseBillRepository;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
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
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Vendor payment recording with multi-bill allocation.
 *
 * On recordPayment():
 *   DR 2010 (Accounts Payable)    = amount − tdsAmount
 *   DR 2030 (TDS Payable)         = tdsAmount (if > 0)
 *   CR paidThroughId (Cash/Bank)   = amount
 *
 * All financial writes go through journalService.postJournal().
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class VendorPaymentService {

    private final VendorPaymentRepository paymentRepository;
    private final PurchaseBillRepository billRepository;
    private final AccountRepository accountRepository;
    private final ContactRepository contactRepository;
    private final OrganisationRepository organisationRepository;
    private final BranchRepository branchRepository;
    private final InvoiceNumberSequenceRepository sequenceRepository;
    private final JournalService journalService;
    private final PurchaseBillService billService;
    private final CurrencyService currencyService;
    private final DefaultAccountService defaultAccountService;
    private final CommentService commentService;

    @Transactional
    public VendorPaymentResponse recordPayment(VendorPaymentRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(request.contactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", request.contactId()));

        if (contact.getContactType() != ContactType.VENDOR && contact.getContactType() != ContactType.BOTH) {
            throw new BusinessException("Contact is not a vendor",
                    "AP_CONTACT_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }

        // Validate paid-through account exists
        Account paidThroughAccount = accountRepository.findByOrgIdAndIdAndIsDeletedFalse(orgId, request.paidThroughId())
                .orElseThrow(() -> BusinessException.notFound("Account", request.paidThroughId()));

        // Validate total allocations match payment amount
        BigDecimal totalAllocated = request.allocations().stream()
                .map(VendorPaymentRequest.AllocationRequest::amountApplied)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        if (totalAllocated.compareTo(request.amount()) != 0) {
            throw new BusinessException(
                    "Total allocations (" + totalAllocated + ") must equal payment amount (" + request.amount() + ")",
                    "AP_ALLOCATION_MISMATCH", HttpStatus.BAD_REQUEST);
        }

        // Validate each allocation against its bill
        for (VendorPaymentRequest.AllocationRequest alloc : request.allocations()) {
            PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(alloc.billId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("PurchaseBill", alloc.billId()));

            if ("DRAFT".equals(bill.getStatus()) || "VOID".equals(bill.getStatus()) || "PAID".equals(bill.getStatus())) {
                throw new BusinessException(
                        "Bill " + bill.getBillNumber() + " is not payable (status: " + bill.getStatus() + ")",
                        "AP_BILL_NOT_PAYABLE", HttpStatus.BAD_REQUEST);
            }

            if (alloc.amountApplied().compareTo(bill.getBalanceDue()) > 0) {
                throw new BusinessException(
                        "Allocation " + alloc.amountApplied() + " exceeds balance due "
                                + bill.getBalanceDue() + " on bill " + bill.getBillNumber(),
                        "AP_ALLOCATION_EXCEEDS_BALANCE", HttpStatus.BAD_REQUEST);
            }
        }

        // Exchange rate
        BigDecimal exchangeRate = currencyService.getRate("INR", org.getBaseCurrency(), request.paymentDate());
        BigDecimal baseAmount = request.amount().multiply(exchangeRate).setScale(2, RoundingMode.HALF_UP);

        // Generate payment number
        int periodYear = billService.computeFiscalYear(request.paymentDate(), org.getFiscalYearStart());
        String paymentNumber = billService.generateNumber(orgId, "VPAY", periodYear);

        // ── Post journal: DR AP (+TDS), CR Cash/Bank ────────────

        List<JournalLineRequest> journalLines = new ArrayList<>();

        BigDecimal apDebit = request.amount().subtract(request.tdsAmount());
        journalLines.add(new JournalLineRequest(
                defaultAccountService.getCode(orgId, DefaultAccountPurpose.AP),
                apDebit, BigDecimal.ZERO,
                "AP cleared: " + paymentNumber,
                null, null));

        if (request.tdsAmount().compareTo(BigDecimal.ZERO) > 0) {
            journalLines.add(new JournalLineRequest(
                    defaultAccountService.getCode(orgId, DefaultAccountPurpose.TDS_PAYABLE),
                    request.tdsAmount(), BigDecimal.ZERO,
                    "TDS: " + paymentNumber,
                    null, null));
        }

        journalLines.add(new JournalLineRequest(
                paidThroughAccount.getCode(),
                BigDecimal.ZERO, request.amount(),
                "Payment " + paymentNumber + " to vendor",
                null, null));

        JournalPostRequest journalRequest = new JournalPostRequest(
                request.paymentDate(),
                "Vendor Payment " + paymentNumber,
                "AP",
                null,
                journalLines,
                true);

        JournalEntry journalEntry = journalService.postJournal(journalRequest);

        // ── Resolve branch ──────────────────────────────────────

        UUID branchId = request.branchId() != null
                ? request.branchId()
                : branchRepository.findByOrgIdAndIsDefaultTrueAndIsDeletedFalse(orgId)
                        .map(Branch::getId).orElse(null);

        // ── Create payment record ───────────────────────────────

        VendorPayment payment = VendorPayment.builder()
                .orgId(orgId)
                .branchId(branchId)
                .contactId(contact.getId())
                .paymentNumber(paymentNumber)
                .paymentDate(request.paymentDate())
                .amount(request.amount())
                .currency("INR")
                .exchangeRate(exchangeRate)
                .baseAmount(baseAmount)
                .paymentMode(request.paymentMode())
                .paidThroughId(request.paidThroughId())
                .referenceNumber(request.referenceNumber())
                .tdsAmount(request.tdsAmount())
                .tdsSection(request.tdsSection())
                .notes(request.notes())
                .journalEntryId(journalEntry.getId())
                .createdBy(userId)
                .build();

        // Create allocations and update each bill
        for (VendorPaymentRequest.AllocationRequest allocReq : request.allocations()) {
            VendorPaymentAllocation allocation = VendorPaymentAllocation.builder()
                    .purchaseBillId(allocReq.billId())
                    .amountApplied(allocReq.amountApplied())
                    .build();
            payment.addAllocation(allocation);

            PurchaseBill bill = billRepository.findByIdAndOrgIdAndIsDeletedFalse(allocReq.billId(), orgId)
                    .orElseThrow(() -> BusinessException.notFound("PurchaseBill", allocReq.billId()));
            billService.updatePaymentStatus(bill, allocReq.amountApplied());

            commentService.addSystemComment("BILL", bill.getId(),
                    "Payment of \u20b9" + allocReq.amountApplied() + " made (" + request.paymentMode() + ")");
        }

        payment = paymentRepository.save(payment);

        // Reduce vendor's outstanding AP
        contact.setOutstandingAp(contact.getOutstandingAp().subtract(request.amount()));
        contactRepository.save(contact);

        log.info("Vendor payment {} recorded: {} allocated across {} bills",
                payment.getPaymentNumber(), payment.getAmount(), request.allocations().size());
        return toResponse(payment);
    }

    // ── Queries ─────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public VendorPaymentResponse getPaymentResponse(UUID paymentId) {
        return toResponse(getPayment(paymentId));
    }

    public VendorPayment getPayment(UUID paymentId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorPayment", paymentId));
    }

    @Transactional(readOnly = true)
    public Page<VendorPaymentResponse> listPayments(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByOrgIdAndIsDeletedFalseOrderByPaymentDateDesc(orgId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<VendorPaymentResponse> listPaymentsByVendor(UUID contactId, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByOrgIdAndContactIdAndIsDeletedFalseOrderByPaymentDateDesc(orgId, contactId, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public Page<VendorPaymentResponse> listPaymentsFiltered(
            UUID contactId, LocalDate dateFrom, LocalDate dateTo, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findFiltered(orgId, contactId, dateFrom, dateTo, pageable)
                .map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public List<VendorPaymentResponse> listPaymentsForBill(UUID billId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return paymentRepository.findByOrgIdAndBillId(orgId, billId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional
    public VendorPaymentResponse voidPayment(UUID paymentId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        VendorPayment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorPayment", paymentId));

        // Reverse journal entry
        if (payment.getJournalEntryId() != null) {
            journalService.reverseEntry(payment.getJournalEntryId());
        }

        // Restore bill payment statuses
        for (VendorPaymentAllocation alloc : payment.getAllocations()) {
            PurchaseBill bill = billRepository.findById(alloc.getPurchaseBillId()).orElse(null);
            if (bill != null) {
                BigDecimal newAmountPaid = bill.getAmountPaid().subtract(alloc.getAmountApplied());
                if (newAmountPaid.compareTo(BigDecimal.ZERO) <= 0) {
                    bill.setAmountPaid(BigDecimal.ZERO);
                    bill.setBalanceDue(bill.getTotalAmount());
                    bill.setStatus("OPEN");
                } else {
                    bill.setAmountPaid(newAmountPaid);
                    bill.setBalanceDue(bill.getTotalAmount().subtract(newAmountPaid));
                    bill.setStatus("PARTIALLY_PAID");
                }
                billRepository.save(bill);

                commentService.addSystemComment("BILL", bill.getId(),
                        "Payment of \u20b9" + alloc.getAmountApplied() + " reversed (payment voided)");
            }
        }

        // Restore vendor's outstanding AP
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(payment.getContactId(), orgId)
                .orElse(null);
        if (contact != null) {
            contact.setOutstandingAp(contact.getOutstandingAp().add(payment.getAmount()));
            contactRepository.save(contact);
        }

        payment.setDeleted(true);
        payment = paymentRepository.save(payment);

        log.info("Vendor payment {} voided", payment.getPaymentNumber());
        return toResponse(payment);
    }

    // ── Response mapping ────────────────────────────────────────

    public VendorPaymentResponse toResponse(VendorPayment payment) {
        Contact contact = contactRepository.findById(payment.getContactId()).orElse(null);

        List<VendorPaymentResponse.AllocationResponse> allocResponses = payment.getAllocations().stream()
                .map(a -> {
                    PurchaseBill bill = billRepository.findById(a.getPurchaseBillId()).orElse(null);
                    return new VendorPaymentResponse.AllocationResponse(
                            a.getId(),
                            a.getPurchaseBillId(),
                            bill != null ? bill.getBillNumber() : null,
                            a.getAmountApplied());
                })
                .toList();

        return new VendorPaymentResponse(
                payment.getId(), payment.getContactId(),
                contact != null ? contact.getDisplayName() : null,
                payment.getPaymentNumber(), payment.getPaymentDate(),
                payment.getAmount(), payment.getCurrency(),
                payment.getPaymentMode(), payment.getPaidThroughId(),
                payment.getReferenceNumber(), payment.getTdsAmount(),
                payment.getNotes(), payment.getJournalEntryId(),
                allocResponses, payment.getCreatedAt());
    }
}
